defmodule BittorrentClient.Peer.GenServerImpl do
  @moduledoc """
  Peer worker to handle peer connections
  https://wiki.theory.org/index.php/BitTorrentSpecification#Peer_wire_protocol_.28TCP.29
  """
  @behaviour BittorrentClient.Peer
  use GenServer
  require Bitwise
  require Logger
  alias BittorrentClient.TCPConn, as: TCPConn
  alias BittorrentClient.Peer.Data, as: PeerData
  alias BittorrentClient.Peer.TorrentTrackingInfo, as: TorrentTrackingInfo
  alias BittorrentClient.Peer.Protocol, as: PeerProtocol
  alias BittorrentClient.Peer.Supervisor, as: PeerSupervisor
  alias BittorrentClient.Peer.BitUtility, as: BitUtil
  alias String.Chars, as: Chars

  @torrent_impl Application.get_env(:bittorrent_client, :torrent_impl)
  @tcp_conn_impl Application.get_env(:bittorrent_client, :tcp_conn_impl)
  @peer_id Application.get_env(:bittorrent_client, :peer_id)

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
      # TODO:  move this data out of  torrent tracking info to check against parent process
      num_pieces: length(parsed_piece_hashes),
      piece_hashes: parsed_piece_hashes,
      piece_table: %{},
      bits_recieved: 0,
      piece_buffer: <<>>
    }

    peer_data = %PeerData{
      id: Application.fetch_env!(:bittorrent_client, :peer_id),
      handshake_check: false,
      need_piece: true,
      filename: filename,
      state: :we_choke,
      torrent_tracking_info: torrent_track_info,
      known_indexes: [],
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
    timer = :erlang.start_timer(peer_data.interval, self(), :send_message)
    Logger.info("Starting peer worker for #{peer_data.name}")

    case @tcp_conn_impl.connect(peer_data.peer_ip, peer_data.peer_port, []) do
      {:ok, sock} ->
        setup_handshake(sock, timer, peer_data)

      {:error, msg} ->
        err_msg =
          "#{peer_data.name} could not send initial handshake to peer: #{msg}"

        Logger.error(err_msg)
        raise err_msg
        # will never return {:error, {peer_data}}
    end
  end

  def terminate(_reason, {peer_data}) do
    _ = cleanup(peer_data)
    Logger.info("Terminating peer worker for #{peer_data.name}")
    :normal
  end

  @spec setup_handshake(TCPConn.t(), reference(), PeerData.t()) ::
          {:ok, PeerData.t()} | {:error, binary()}
  defp setup_handshake(sock, timer, peer_data) do
    # send bitfield msg after handshake. get completed list and create bitfield
    # for now sending empty bitfiled
    bf_msg = PeerProtocol.encode(:bitfield, <<>>)
    Logger.debug("#{peer_data.name} is sending bitfield : #{bf_msg}}")

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

        {:error, {peer_data}}

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
    :ok = @tcp_conn_impl.close(peer_data.socket)
  end

  # these handle_info calls come from the socket for attention
  def handle_info({:error, reason}, {peer_data}) do
    Logger.error("#{peer_data.name} has come across and error: #{reason}")

    # terminate genserver gracefully?
    PeerSupervisor.terminate_child(peer_data.id)
    {:noreply, {peer_data}}
  end

  # :DONE
  def handle_info({:timeout, timer, :send_message}, {peer_data}) do
    # this should look at the state of the message to determine what to send
    # to peer. the timer sends a signal to the peer handle when it is time to
    # send over a message.
    # Logger.debug( "What is this: #{inspect peer_data}")
    :erlang.cancel_timer(timer)

    Logger.debug(
      "#{peer_data.name} : timer ended, current state: #{
        inspect(peer_data.state)
      }"
    )

    new_peer_data = send_message(peer_data.state, peer_data)

    Logger.debug(
      "#{peer_data.name} : sent messages, new state: #{
        inspect(new_peer_data.state)
      }"
    )

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

    {msgs, _leftovers} =
      buff
      |> PeerProtocol.tcp_buff_to_encoded_msg()
      |> PeerProtocol.decode()

    Logger.debug(fn ->
      "#{peer_data.name} has recieved the following message buff #{
        inspect(msgs)
      }"
    end)

    new_peer_data = loop_msgs(msgs, socket, peer_data)
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
    PeerSupervisor.terminate_child(peer_data.id)
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
      Logger.error(
        "INFO HASH did not match actual: #{inspect(actual)} != expected: #{
          inspect(expected)
        }"
      )

      Logger.error("Not acting upon this")
    end

    Logger.debug(fn -> "Handshake MSG: #{peer_data.name}" end)
    %PeerData{peer_data | state: :we_choke, handshake_check: true}
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
        |> Map.get_and_update(:known_indexes, fn lst ->
          [msg.piece_index | lst]
        end)

      {:error, errmsg} ->
        Logger.error(
          "#{peer_data.name} failed to add #{msg.piece_index} to it's table : #{
            errmsg
          }"
        )

        peer_data
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
          "#{peer_data.name} successfully added #{new_piece_indexes} to it's table."
        end)

        peer_data
        |> Map.put(:torrent_tracking_info, new_ttinfo_state)
        |> Map.put(:known_indexes, new_piece_indexes)

      {:error, errmsg} ->
        Logger.error(
          "#{peer_data.name} failed to add #{new_piece_indexes} to it's table : #{
            errmsg
          }"
        )

        peer_data
    end
  end

  def handle_message(:piece, msg, _socket, peer_data) do
    Logger.debug(fn -> "Piece MSG: #{peer_data.name}" end)
    ttinfo = peer_data.torrent_tracking_info

    if msg.piece_index == ttinfo.expected_piece_index do
      Logger.debug(fn ->
        "Piece MSG: #{peer_data.name} recieved #{inspect(msg)}"
      end)

      {offset, _} = Integer.parse(msg.block_offsest)
      {length, _} = Integer.parse(msg.block_length)

      case TorrentTrackingInfo.add_piece_index_data(
             ttinfo,
             msg.piece_index,
             offset,
             length,
             <<msg.block::size(length)>>
           ) do
        {:ok, new_ttinfo} ->
          Logger.debug(fn ->
            "Piece MSG: #{peer_data.name} successfully added piece data to table"
          end)

          %PeerData{peer_data | torrent_tracking_info: new_ttinfo}

        {:error, msg} ->
          Logger.error(
            "Piece MSG: #{peer_data.name} could not handle piece message correctly: #{
              msg
            }"
          )

          peer_data
      end
    else
      Logger.debug(fn ->
        "Piece MSG: #{peer_data.name} has recieved the wrong piece: #{
          msg.piece_index
        }, expected: #{peer_data.piece_index}"
      end)

      peer_data
    end
  end

  def handle_message(:cancel, _msg, _socket, peer_data) do
    Logger.debug(fn ->
      "Cancel MSG: #{peer_data.name}, Close port, kill process"
    end)

    peer_data
  end

  def handle_message(:port, _msg, _socket, peer_data) do
    Logger.debug(fn ->
      "Port MSG: #{peer_data.name}, restablish new connect for new port"
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

  @spec loop_msgs(list(map()), TCPConn.t(), PeerData.t()) :: PeerData.t()
  def loop_msgs([msg | msgs], socket, peer_data) do
    new_peer_data = handle_message(msg.type, msg, socket, peer_data)
    loop_msgs(msgs, socket, new_peer_data)
  end

  def loop_msgs([], _, peer_data) do
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
    # if pieces are known, send interested msg

    {:ok, new_peer_data} = handle_serving_behaviour(peer_data)
    new_peer_data
  end

  def send_message(:me_interest_it_choke, peer_data) do
    case handle_leeching_behaviour(peer_data) do
      {:ok, new_peer_data} ->
        new_peer_data

      {:error, reason} ->
        Logger.error("#{peer_data.name} : #{reason}")
        peer_data
    end
  end

  def send_message(:we_interest, peer_data) do
    Logger.debug("#{peer_data.name} : in we_interest state, doing nothing")
    msg1 = PeerProtocol.encode(:keep_alive)
    # This function should request a piece and serve a requested piece
    @tcp_conn_impl.send(peer_data.socket, msg1)
    peer_data
  end

  def send_message(:we_choke, peer_data) do
    # if pieces are known, send interested msg
    # also if pieces are requested from peer connection, send unchoke msg

    case @torrent_impl.get_completed_piece_list(
           peer_data.torrent_tracking_info.id
         ) do
      {:ok, lst} ->
        interest_msg = PeerProtocol.encode(:interested)
        @tcp_conn_impl.send(peer_data.socket, interest_msg)
        peer_data

      {:error, msg} ->
        Logger.error(
          "#{peer_data.name} could not retrieve completed list from parent proc: #{
            msg
          }"
        )

        peer_data
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

  @spec handle_leeching_behaviour(PeerData.t()) ::
          {:ok, PeerData.t()} | {:error, binary()}
  defp handle_leeching_behaviour(peer_data) do
    if peer_data.need_piece do
      # if the is not a piece in progress, request a new piece
      Logger.debug(
        "#{peer_data.name} : needs a new piece to work on, requesting work from torrent process"
      )

      handle_new_piece_request(peer_data)
    else
      # else continue with current piece
      Logger.debug(
        "#{peer_data.name} : currently working on a piece #{
          peer_data.torrent_tracking_info.expected_piece_index
        }"
      )

      handle_current_piece_request(peer_data)
    end
  end

  @spec handle_new_piece_request(PeerData.t()) ::
          {:ok, PeerData.t()} | {:error, binary()}
  defp handle_new_piece_request(peer_data) do
    msg1 = PeerProtocol.encode(:keep_alive)

    case @torrent_impl.get_next_piece_index(
           peer_data.torrent_id,
           Map.keys(peer_data.torrent_tracking_info.piece_table)
         ) do
      {:ok, next_piece_index} ->
        next_sub_piece_index = 0

        msg2 =
          PeerProtocol.encode(:request, next_piece_index, next_sub_piece_index)

        {:ok, _} = @tcp_conn_impl.send(peer_data.socket, msg1 <> msg2)

        new_ttinfo =
          peer_data.torrent_tracking_info
          |> Map.put(:expected_piece_index, next_piece_index)
          |> Map.put(:expected_sub_piece_index, next_sub_piece_index)

        new_peer_data =
          peer_data
          |> Map.put(:torrent_tracking_info, new_ttinfo)
          |> Map.put(:need_piece, false)

        {:ok, new_peer_data}

      {:error, reason} ->
        # send a not_interested request to peer connection
        msg2 = PeerProtocol.encode(:not_interested)
        {:ok} = @tcp_conn_impl.send(peer_data.socket, msg1 <> msg2)
        {:error, reason}
    end
  end

  @spec handle_current_piece_request(PeerData.t()) ::
          {:ok, PeerData.t()} | {:error, binary()}
  defp handle_current_piece_request(peer_data) do
    msg1 = PeerProtocol.encode(:keep_alive)

    msg2 =
      PeerProtocol.encode(
        :request,
        peer_data.torrent_tracking_info.expected_piece_index,
        peer_data.torrent_tracking_info.expected_sub_piece_index
      )

    {:ok, _} = @tcp_conn_impl.send(peer_data.socket, msg1 <> msg2)
    {:ok, peer_data}
  end

  @spec handle_serving_behaviour(PeerData.t()) ::
          {:ok, PeerData.t()} | {:error, binary()}
  def handle_serving_behaviour(peer_data) do
    {:error,
     "#{peer_data.name} : is trying to serve piece but this is not implemented"}
  end
end
