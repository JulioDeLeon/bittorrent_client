defmodule BittorrentClient.Peer.GenServerImpl do
  @moduledoc """
  Peer worker to handle peer connections
  https://wiki.theory.org/index.php/BitTorrentSpecification#Peer_wire_protocol_.28TCP.29
  """
  @behaviour BittorrentClient.Peer
  use GenServer
  require Bitwise
  require Logger
  alias BittorrentClient.Peer.BitUtility, as: BitUtil
  alias BittorrentClient.Peer.Data, as: PeerData
  alias BittorrentClient.Peer.Protocol, as: PeerProtocol
  alias BittorrentClient.Peer.Supervisor, as: PeerSupervisor
  alias BittorrentClient.Peer.TorrentTrackingInfo, as: TorrentTrackingInfo
  alias BittorrentClient.TCPConn, as: TCPConn
  alias String.Chars, as: Chars

  @torrent_impl Application.get_env(:bittorrent_client, :torrent_impl)
  @tcp_conn_impl Application.get_env(:bittorrent_client, :tcp_conn_impl)
  @peer_id Application.get_env(:bittorrent_client, :peer_id)
  @default_block_size Application.get_env(
                        :bittorrent_client,
                        :default_block_size
                      )
  # -------------------------------------------------------------------------------
  # GenServer Callbacks
  # -------------------------------------------------------------------------------
  def start_link(
        {metainfo, torrent_id, info_hash, filename, interval, ip, port}
      ) do
    name = "#{torrent_id}_#{ip_to_str(ip)}_#{port}"

    parsed_piece_hashes =
      metainfo.info.pieces
      |> :binary.bin_to_list()
      |> Enum.chunk_every(20)
      |> Enum.map(fn x -> Chars.to_string(x) end)

    torrent_track_info = %TorrentTrackingInfo{
      id: torrent_id,
      infohash: info_hash,
      piece_length: metainfo.info."piece length",
      request_queue: [],
      # TODO:  move this data out of  torrent tracking info to check against parent process
      num_pieces: length(parsed_piece_hashes),
      piece_hashes: parsed_piece_hashes,
      piece_table: %{},
      bytes_received: 0,
      need_piece: true
    }

    peer_data = %PeerData{
      id: Application.fetch_env!(:bittorrent_client, :peer_id),
      handshake_check: false,
      need_piece: true,
      filename: filename,
      state: :we_choke,
      torrent_tracking_info: torrent_track_info,
      running_buffer: <<>>,
      timer: nil,
      interval: interval,
      peer_ip: ip,
      peer_port: port,
      name: name
    }

    GenServer.start_link(
      __MODULE__,
      {peer_data},
      name: {:global, {:btc_peerworker, name}}
    )
  end

  def init({peer_data}) do
    Process.flag(:trap_exit, true)
    timer = :erlang.start_timer(peer_data.interval, self(), :send_message)
    Logger.info("Starting peer worker for #{peer_data.name}")

    case @tcp_conn_impl.connect(peer_data.peer_ip, peer_data.peer_port,
           packet: :raw
         ) do
      {:ok, sock} ->
        case setup_handshake(sock, timer, peer_data) do
          {:ok, new_peer_data} ->
            {:ok, new_peer_data}

          {:error, _} ->
            err_msg = "#{peer_data.name} failed initial handshake!"
            Logger.error(err_msg)
            raise err_msg
        end

      {:error, msg} ->
        err_msg =
          "#{peer_data.name} could not send initial handshake to peer: #{msg}"

        Logger.error(err_msg)
        raise err_msg
    end
  end

  def terminate(_reason, {peer_data}) do
    _ = cleanup(peer_data)
    Logger.info("Terminating peer worker for #{peer_data.name}")
    :normal
  end

  # these handle_info calls come from the socket for attention
  def handle_info({:error, reason}, {peer_data}) do
    err_msg = "#{peer_data.name} has come across and error: #{reason}"
    Logger.error(err_msg)

    # terminate genserver gracefully?
    PeerSupervisor.terminate_child(peer_data.name)
    # TODO: if the process does not terminate, raise error here
    {:noreply, {peer_data}}
  end

  # :DONE
  def handle_info({:timeout, timer, :send_message}, {peer_data}) do
    # this should look at the state of the message to determine what to send
    # to peer. the timer sends a signal to the peer handle when it is time to
    # send over a message.
    :erlang.cancel_timer(timer)

    Logger.debug(fn ->
      "#{peer_data.name} : timer ended, current state: #{
        inspect(peer_data.state)
      }"
    end)

    new_peer_data = send_message(peer_data.state, peer_data)

    Logger.debug(fn ->
      "#{peer_data.name} : sent messages, new state: #{
        inspect(new_peer_data.state)
      }"
    end)

    timer = :erlang.start_timer(peer_data.interval, self(), :send_message)

    {:noreply, {%PeerData{new_peer_data | timer: timer}}}
  end

  # :DONE
  def handle_info({:tcp, socket, buff}, {peer_data}) do
    # this should handle what ever msgs that received from the peer
    # the tcp socket alerts the peer handler when there are messages to be read

    Logger.debug(fn ->
      "#{peer_data.name} has received the following message raw #{inspect(buff)}"
    end)

    new_peer_data = handle_msg_buffer(peer_data, socket, buff)

    # Logger.debug( "Returning this: #{inspect ret}")
    {:noreply, {new_peer_data}}
  end

  # Extra use cases
  # :DONE
  def handle_info({:tcp_passive, socket}, {peer_data}) do
    :inet.setopts(socket, active: 1)
    {:noreply, {peer_data}}
  end

  # :DONE
  def handle_info({:tcp_closed, _socket}, {peer_data}) do
    Logger.error("#{peer_data.name} has closed socket, should terminate")

    # Gracefully stop this peer process OR get a new peer
    PeerSupervisor.terminate_child(peer_data.name)
    {:noreply, {peer_data}}
  end

  # :DONE
  def whereis(pworker_id) do
    :global.whereis_name({:btc_peerworker, pworker_id})
  end

  # :DONE
  def handle_message(:keep_alive, _msg, _socket, peer_data) do
    Logger.debug(fn -> "Stay-Alive MSG: #{peer_data.name}" end)
    peer_data
  end

  def handle_message(:handshake, msg, _socket, peer_data) do
    expected = peer_data.torrent_tracking_info.infohash
    actual = msg.info_hash

    if actual != expected do
      err =
        "INFO HASH did not match actual: #{inspect(actual)} != expected: #{
          inspect(expected)
        }"

      Logger.error(err)

      PeerSupervisor.terminate_child(peer_data.name)
      raise err
    else
      Logger.debug(fn -> "Handshake MSG: #{peer_data.name}" end)

      TorrentTrackingInfo.notify_torrent_of_connection(
        peer_data.torrent_tracking_info,
        peer_data.name,
        peer_data.peer_ip,
        peer_data.peer_port
      )

      %PeerData{peer_data | state: :we_choke, handshake_check: true}
    end
  end

  # :DONE
  def handle_message(:choke, _msg, _socket, peer_data) do
    Logger.debug(fn ->
      "Choke MSG: #{peer_data.name} will stop leaching data"
    end)

    case peer_data.state do
      :we_interest ->
        %PeerData{peer_data | state: :me_choke_it_interest}

      :me_interest_it_choke ->
        %PeerData{peer_data | state: :we_choke}

      _ ->
        peer_data
    end
  end

  # :DONE
  def handle_message(:unchoke, _msg, _socket, peer_data) do
    Logger.debug(fn -> "Unchoke MSG: #{peer_data.name} will start leaching" end)

    case peer_data.state do
      :we_choke ->
        %PeerData{peer_data | state: :me_interest_it_choke}

      :me_choke_it_interest ->
        %PeerData{peer_data | state: :we_interest}

      _ ->
        peer_data
    end
  end

  # :DONE
  def handle_message(:interested, _msg, _socket, peer_data) do
    Logger.debug(fn ->
      "Interested MSG: #{peer_data.name} will start serving data"
    end)

    case peer_data.state do
      :we_choke ->
        %PeerData{peer_data | state: :me_choke_it_interest}

      :me_interest_it_choke ->
        %PeerData{peer_data | state: :we_interest}

      _ ->
        peer_data
    end
  end

  # :DONE
  def handle_message(:not_interested, _msg, _socket, peer_data) do
    Logger.debug(fn ->
      "Not_interested MSG: #{peer_data.name} will stop serving data"
    end)

    case peer_data.state do
      :we_interest ->
        %PeerData{peer_data | state: :me_interest_it_choke}

      :me_choke_it_interest ->
        %PeerData{peer_data | state: :we_choke}

      _ ->
        peer_data
    end
  end

  # :DONE?
  def handle_message(:have, msg, _socket, peer_data) do
    Logger.debug(fn -> "Have MSG: #{peer_data.name}" end)
    ttinfo_state = peer_data.torrent_tracking_info

    case TorrentTrackingInfo.populate_single_piece(
           ttinfo_state,
           peer_data.id,
           msg.piece_index
         ) do
      {:ok, new_ttinfo_state} ->
        Logger.debug(fn ->
          "#{peer_data.name} successfully added #{msg.piece_index} to it's table."
        end)

        peer_data
        |> Map.put(:torrent_tracking_info, new_ttinfo_state)

      {:error, errmsg} ->
        Logger.error(errmsg)
        PeerSupervisor.terminate_child(peer_data.name)
        raise errmsg
    end
  end

  # :DONE?
  def handle_message(:bitfield, msg, _socket, peer_data) do
    Logger.debug(fn -> "Bitfield MSG: #{peer_data.name}" end)
    ttinfo_state = peer_data.torrent_tracking_info
    new_piece_indexes = BitUtil.parse_bitfield(msg.bitfield)

    case TorrentTrackingInfo.populate_multiple_pieces(
           ttinfo_state,
           peer_data.id,
           new_piece_indexes
         ) do
      {:ok, new_ttinfo_state} ->
        Logger.debug(fn ->
          "#{peer_data.name} successfully added bitfield to it's table."
        end)

        peer_data
        |> Map.put(:torrent_tracking_info, new_ttinfo_state)

      {:error, errmsg} ->
        Logger.error(errmsg)
        PeerSupervisor.terminate_child(peer_data.name)
        raise errmsg
    end
  end

  def handle_message(:piece, msg, _socket, peer_data) do
    Logger.debug(fn -> "Piece MSG: #{peer_data.name}" end)
    ttinfo = peer_data.torrent_tracking_info

    # TODO check piece hash here or when full piece is downloaded?

    if msg.piece_index == ttinfo.expected_piece_index do
      Logger.debug(fn ->
        "Piece MSG: #{peer_data.name} received #{inspect(msg)}"
      end)

      offset = msg.block_offset
      length = msg.block_length

      case TorrentTrackingInfo.add_piece_index_data(
             ttinfo,
             msg.piece_index,
             offset,
             length,
             msg.block
           ) do
        {:ok, new_ttinfo} ->
          Logger.debug(fn ->
            "Piece MSG: #{peer_data.name} successfully added piece data to table"
          end)

          %PeerData{peer_data | torrent_tracking_info: new_ttinfo}

        {:error, errmsg} ->
          Logger.error(errmsg)
          PeerSupervisor.terminate_child(peer_data.name)
          raise errmsg
      end
    else
      errmsg =
        "Piece MSG: #{peer_data.name} has received the wrong piece: #{
          msg.piece_index
        }, expected: #{peer_data.piece_index}"

      Logger.error(errmsg)

      PeerSupervisor.terminate_child(peer_data.name)
      raise errmsg
    end
  end

  def handle_message(:cancel, _msg, _socket, peer_data) do
    Logger.debug(fn ->
      "Cancel MSG: #{peer_data.name}, Stop sending the requested piece"
    end)

    peer_data
  end

  def handle_message(:port, _msg, _socket, peer_data) do
    Logger.debug(fn ->
      "Port MSG: #{peer_data.name}, reestablish new connect for new port"
    end)

    peer_data
  end

  def handle_message(unknown_type, msg, _socket, peer_data) do
    Logger.error(
      "#{unknown_type} MSG: #{peer_data.name} could not handle this message: #{
        inspect(msg)
      }"
    )

    peer_data
  end

  # -------------------------------------------------------------------------------
  # Api Calls
  # -------------------------------------------------------------------------------

  # -------------------------------------------------------------------------------
  # Utility Functions
  # ------------------------------------------------------------------------------
  @spec loop_msgs(PeerData.t(), list(map()), TCPConn.t()) :: PeerData.t()
  def loop_msgs(peer_data, [msg | msgs], socket) do
    new_peer_data = handle_message(msg.type, msg, socket, peer_data)
    loop_msgs(new_peer_data, msgs, socket)
  end

  def loop_msgs(peer_data, [], _) do
    peer_data
  end

  def ip_to_str({f, s, t, fr}) do
    "#{f}.#{s}.#{t}.#{fr}"
  end

  def send_handshake(socket, msg) do
    @tcp_conn_impl.send(socket, msg)
  end

  def connect(ip, port) do
    @tcp_conn_impl.connect(ip, port, [:binary, active: 1], 2_000)
  end

  @spec send_message(PeerData.state(), PeerData.t()) :: PeerData.t()
  def send_message(:me_choke_it_interest, peer_data) do
    init_msg = PeerProtocol.encode(:keep_alive)

    {new_peer_data, msgs} =
      {peer_data, init_msg}
      |> create_message(:interested)
      |> create_message(:seed)

    case @tcp_conn_impl.send(peer_data.socket, msgs) do
      :ok ->
        new_peer_data

      {:error, errmsg} ->
        Logger.error(errmsg)
        PeerSupervisor.terminate_child(peer_data.name)
        raise errmsg
    end
  end

  def send_message(:me_interest_it_choke, peer_data) do
    init_msg = PeerProtocol.encode(:keep_alive)

    {new_peer_data, msgs} =
      {peer_data, init_msg}
      |> create_message(:interested)
      |> create_message(:leech)
      |> create_message(:requested)

    case @tcp_conn_impl.send(peer_data.socket, msgs) do
      :ok ->
        new_peer_data

      {:error, errmsg} ->
        Logger.error(errmsg)
        PeerSupervisor.terminate_child(peer_data.name)
        raise errmsg
    end
  end

  def send_message(:we_interest, peer_data) do
    init_msg = PeerProtocol.encode(:keep_alive)

    {new_peer_data, msgs} =
      {peer_data, init_msg}
      |> create_message(:interested)
      |> create_message(:leech)
      |> create_message(:requested)
      |> create_message(:seed)

    case @tcp_conn_impl.send(peer_data.socket, msgs) do
      :ok ->
        new_peer_data

      {:error, errmsg} ->
        Logger.error(errmsg)
        PeerSupervisor.terminate_child(peer_data.name)
        raise errmsg
    end
  end

  def send_message(:we_choke, peer_data) do
    known_indexes =
      TorrentTrackingInfo.get_known_pieces(peer_data.torrent_tracking_info)

    req_indexes = peer_data.torrent_tracking_info.request_queue

    if known_indexes == [] && req_indexes == [] do
      Logger.info(
        "#{peer_data.name} is not leeching or seeding pieces, terminating connection."
      )

      # terminating child here will gracefully close tcp connection with peer,
      # no need to send a message
      PeerSupervisor.terminate_child(peer_data.name)
      raise "terminating"
    else
      init_msg = PeerProtocol.encode(:keep_alive)

      {new_peer_data, msgs} =
        {peer_data, init_msg}
        |> create_message(:interested)
        |> create_message(:requested)

      case @tcp_conn_impl.send(peer_data.socket, msgs) do
        :ok ->
          new_peer_data

        {:error, errmsg} ->
          Logger.error(errmsg)
          PeerSupervisor.terminate_child(peer_data.name)
          raise errmsg
      end
    end
  end

  def send_message(_, peer_data) do
    Logger.debug(fn ->
      "#{peer_data.name} is in #{inspect(peer_data.state)} state"
    end)

    peer_data
  end

  def control_initial_handshake({ip, port}) do
    @tcp_conn_impl.connect(ip, port, [])
  end

  @spec create_message({PeerData.t(), binary()}, atom()) ::
          {PeerData.t(), binary()}
  def create_message({peer_data, buff}, :leech) do
    if peer_data.torrent_tracking_info.need_piece do
      # if the is not a piece in progress, request a new piece
      Logger.debug(fn ->
        "#{peer_data.name} : needs a new piece to work on, requesting work from torrent process"
      end)

      handle_new_piece_request({peer_data, buff})
    else
      # else continue with current piece
      Logger.debug(fn ->
        "#{peer_data.name} : currently working on a piece #{
          peer_data.torrent_tracking_info.expected_piece_index
        } offset #{peer_data.torrent_tracking_info.expected_sub_piece_index}"
      end)

      handle_current_piece_request({peer_data, buff})
    end
  end

  def create_message({peer_data, buff}, :interested) do
    known_indexes =
      TorrentTrackingInfo.get_known_pieces(peer_data.torrent_tracking_info)

    need_piece = peer_data.torrent_tracking_info.need_piece

    piece_inflight =
      TorrentTrackingInfo.is_piece_in_progress?(peer_data.torrent_tracking_info)

    msg =
      if (length(known_indexes) > 0 and need_piece) or piece_inflight do
        Logger.debug(fn ->
          "#{peer_data.name} : is interested in peer connection"
        end)

        PeerProtocol.encode(:interested)
      else
        Logger.debug(fn ->
          "#{peer_data.name} : is not interested in peer connection"
        end)

        PeerProtocol.encode(:not_interested)
      end

    {peer_data, buff <> msg}
  end

  def create_message({peer_data, _buff}, :terminate) do
    known_indexes =
      TorrentTrackingInfo.get_known_pieces(peer_data.torrent_tracking_info)

    req_indexes = peer_data.torrent_tracking_info.request_queue

    msg =
      if known_indexes == [] && req_indexes == [] do
        Logger.info(
          "#{peer_data.name} is not leeching or seeding pieces, terminating connection."
        )

        # terminating child here will gracefully close tcp connection with peer,
        # no need to send a message
        PeerSupervisor.terminate_child(peer_data.name)
      else
        PeerProtocol.encode(:keep_alive)
      end

    {peer_data, msg}
  end

  def create_message({peer_data, buff}, anything) do
    Logger.error("#{peer_data.name} : is trying to #{anything}")

    {peer_data, buff}
  end

  @spec handle_new_piece_request({PeerData.t(), binary()}) ::
          {PeerData.t(), binary()}
  defp handle_new_piece_request({peer_data, buff}) do
    case @torrent_impl.get_next_piece_index(
           peer_data.torrent_tracking_info.id,
           Map.keys(peer_data.torrent_tracking_info.piece_table)
         ) do
      {:ok, next_piece_index} ->
        Logger.debug(fn ->
          "#{peer_data.name} : will work on #{next_piece_index}"
        end)

        next_sub_piece_index = 0
        # TODO calculate last block size base on what has been received
        piece_length =
          if peer_data.torrent_tracking_info.piece_length < @default_block_size do
            peer_data.torrent_tracking_info.piece_length
          else
            @default_block_size
          end

        msg =
          PeerProtocol.encode(
            :request,
            next_piece_index,
            next_sub_piece_index,
            piece_length
          )

        new_ttinfo =
          peer_data.torrent_tracking_info
          |> Map.put(:expected_piece_index, next_piece_index)
          |> Map.put(:expected_sub_piece_index, next_sub_piece_index)
          |> Map.put(:expected_piece_length, piece_length)
          |> Map.put(:bytes_recieved, 0)
          |> Map.put(:need_piece, false)

        new_peer_data =
          peer_data
          |> Map.put(:torrent_tracking_info, new_ttinfo)

        {new_peer_data, buff <> msg}

      {:error, reason} ->
        Logger.error("#{peer_data.name} : #{reason}")
        msg = PeerProtocol.encode(:not_interested)
        {peer_data, buff <> msg}
    end
  end

  @spec handle_current_piece_request({PeerData.t(), binary()}) ::
          {PeerData.t(), binary()}
  defp handle_current_piece_request({peer_data, buff}) do
    Logger.debug(fn ->
      "#{peer_data.name} : will continue working on #{
        peer_data.torrent_tracking_info.expected_piece_index
      }"
    end)

    msg =
      PeerProtocol.encode(
        :request,
        peer_data.torrent_tracking_info.expected_piece_index,
        peer_data.torrent_tracking_info.expected_sub_piece_index,
        peer_data.torrent_tracking_info.expected_piece_length
      )

    {peer_data, buff <> msg}
  end

  defp handle_msg_buffer(peer_data, socket, buff) do
    {msgs, leftovers} =
      buff
      |> PeerProtocol.tcp_buff_to_encoded_msg()
      |> (fn bin -> peer_data.running_buffer <> bin end).()
      |> PeerProtocol.decode()

    Logger.debug(fn ->
      "#{peer_data.name} has received the following message buff #{
        inspect(msgs)
      }"
    end)

    new_peer_data =
      peer_data
      |> loop_msgs(msgs, socket)
      |> Map.put(:running_buffer, leftovers)

    new_peer_data
  end

  @spec setup_handshake(TCPConn.t(), reference(), PeerData.t()) :: any()
  defp setup_handshake(sock, timer, peer_data) do
    # send bitfield msg after handshake. get completed list and create bitfield
    # for now sending empty bitfiled
    bf_msg = PeerProtocol.encode(:bitfield, <<>>)

    Logger.debug(fn ->
      "#{peer_data.name} is sending bitfield : #{bf_msg}} TODO : NOT REALLY SENDING BF"
    end)

    # When building the reserved field in handshake, set extension supported to 1
    # reserved bit meanins
    msg =
      PeerProtocol.encode(
        :handshake,
        <<0::size(64)>>,
        peer_data.torrent_tracking_info.infohash,
        @peer_id
      )

    case send_handshake(sock, msg) do
      {:error, msg} ->
        Logger.error(
          "#{peer_data.name} could not send handshake to peer: #{msg}"
        )

        {:error, peer_data}

      _ ->
        {:ok,
         {%PeerData{
            peer_data
            | socket: sock,
              timer: timer
          }}}
    end
  end

  defp cleanup(peer_data) do
    ttinfo = peer_data.torrent_tracking_info
    peer_id = peer_data.name
    TorrentTrackingInfo.notify_torrent_of_disconnection(ttinfo, peer_id, peer_data.peer_ip, peer_data.peer_ip)
    @tcp_conn_impl.close(peer_data.socket)
    :ok
  end
end
