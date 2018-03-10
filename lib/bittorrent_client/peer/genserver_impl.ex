defmodule BittorrentClient.Peer.GenServerImpl do
  @moduledoc """
  Peer worker to handle peer connections
  https://wiki.theory.org/index.php/BitTorrentSpecification#Peer_wire_protocol_.28TCP.29
  """
  @behaviour BittorrentClient.Peer
  use GenServer
  require Bitwise
  require Logger
  alias BittorrentClient.Peer.Data, as: PeerData
  alias BittorrentClient.Peer.TorrentTrackingInfo, as: TorrentTrackingInfo
  alias BittorrentClient.Peer.Protocol, as: PeerProtocol
  alias BittorrentClient.Peer.Supervisor, as: PeerSupervisor

  @torrent_impl Application.get_env(:bittorrent_client, :torrent_impl)
  @tcp_conn_impl Application.get_env(:bittorrent_client, :tcp_conn_impl)

  def start_link(
        {metainfo, torrent_id, info_hash, filename, interval, ip, port}
      ) do
    name = "#{torrent_id}_#{ip_to_str(ip)}_#{port}"

    torrent_track_info = %TorrentTrackingInfo{
      id: torrent_id,
      infohash: info_hash,
      piece_length: metainfo.info."piece length",
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
    Logger.debug(fn -> "Using tcp_conn_imp: #{@tcp_conn_impl}" end)
    sock = @tcp_conn_impl.connect(peer_data.peer_ip, peer_data.peer_port, [])
    # sock = connect(peer_data.peer_ip, peer_data.peer_port)

    msg =
      PeerProtocol.encode(
        :handshake,
        <<0::size(64)>>,
        peer_data.info_hash,
        peer_data.peer_id
      )

    send_handshake(sock, msg)

    {:ok,
     {%PeerData{
        peer_data
        | socket: sock,
          timer: timer
      }}}
  end

  # these handle_info calls come from the socket for attention
  def handle_info({:error, reason}, peer_data) do
    Logger.error("#{peer_data.name} has come across and error: #{reason}")

    # terminate genserver gracefully?
    PeerSupervisor.terminate_child(peer_data.peer_id)
    {:noreply, peer_data}
  end

  # :DONE
  def handle_info({:timeout, timer, :send_message}, {peer_data}) do
    # this should look at the state of the message to determine what to send
    # to peer. the timer sends a signal to the peer handle when it is time to
    # send over a message.
    # Logger.debug( "What is this: #{inspect peer_data}")
    :erlang.cancel_timer(timer)
    new_state = send_message(peer_data.state, peer_data)
    timer = :erlang.start_timer(peer_data.interval, self(), :send_message)

    {:noreply,
     {%PeerData{
        new_state
        | timer: timer
      }}}
  end

  # :DONE
  def handle_info({:tcp, socket, msg}, peer_data) do
    # this should handle what ever msgs that received from the peer
    # the tcp socket alerts the peer handler when there are messages to be read
    {msgs, _} = PeerProtocol.decode(msg)
    {a_pd} = peer_data

    # Logger.debug( "Messages #{inspect msgs} for #{inspect peer_data}")
    ret = loop_msgs(msgs, socket, a_pd)
    # Logger.debug( "Returning this: #{inspect ret}")
    {:noreply, {ret}}
  end

  # Extra use cases
  # :DONE
  def handle_info({:tcp_passive, socket}, peer_data) do
    :inet.setopts(socket, active: 1)
    {:noreply, peer_data}
  end

  # :DONE
  def handle_info({:tcp_closed, _socket}, {peer_data}) do
    Logger.info("#{peer_data.name} has closed socket, should terminate")

    # Gracefully stop this peer process OR get a new peer
    PeerSupervisor.terminate_child(peer_data.peer_id)
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
    expected = Map.get(peer_data, "info_hash")

    if msg != expected do
      Logger.error("INFO HASH did not match #{msg} != #{expected}")
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

        %PeerData{
          peer_data
          | torrent_tracking_info: new_ttinfo_state
        }

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
    new_piece_indexes = parse_bitfield(msg.bitfield, [], 0)

    case TorrentTrackingInfo.populate_multiple_pieces(
           ttinfo_state,
           peer_data.id,
           new_piece_indexes
         ) do
      {:ok, new_ttinfo_state} ->
        Logger.debug(fn ->
          "#{peer_data.name} successfully added #{new_piece_indexes} to it's table."
        end)

        %PeerData{peer_data | torrent_tracking_info: new_ttinfo_state}

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
    if msg.piece_index == peer_data.piece_index do
      Logger.debug(fn ->
        "Piece MSG: #{peer_data.name} recieved #{inspect(msg)}"
      end)
      {offset, _} = Integer.parse(msg.block_offsest)
      {length, _} = Integer.parse(msg.block_length)
      <<before::size(offset), aft>> = peer_data.piece_buffer
      new_buffer = <<before, msg.block::size(length), aft>>
      total_recieved_amount = ttinfo.bits_recieved + msg.block_length

      piece_status =
        if total_recieved_amount == peer_data.piece_length do
          :incomplete
        else
          :completed
        end

      if piece_status == :completed do
        {status, _} =
          @torrent_impl.mark_piece_index_done(
            peer_data.torrent_id,
            peer_data.piece_index,
            new_buffer
          )

        case status do
          :ok ->
            Logger.debug(fn ->
              "#{peer_data.name} has completed #{peer_data.piece_index}"
            end)

          _ ->
            Logger.error(
              "#{peer_data.name} could not complete #{peer_data.piece_index}"
            )
        end

        new_piece_table = Map.drop(peer_data.piece_table, peer_data.piece_index)

        %PeerData{
          peer_data
          | torrent_tracking_info: %TorrentTrackingInfo{
              peer_data.torrent_tracking_info
              | piece_buffer: new_buffer,
                bits_recieved: new_recieved,
                piece_table: new_piece_table
            }
        }
      else
        new_piece_table = %{peer_data.piece_data | piece_index: piece_status}

        %PeerData{
          peer_data
          | torrent_tracking_info: %TorrentTrackingInfo{
              peer_data.torrent_tracking_info
              | piece_buffer: new_buffer,
                bits_recieved: new_recieved,
                piece_table: new_piece_table
            },
            need_piece: true
        }
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

  def loop_msgs([msg | msgs], socket, peer_data) do
    new_peer_data = handle_message(msg.type, msg, socket, peer_data)
    loop_msgs(msgs, socket, new_peer_data)
  end

  def loop_msgs(_, _, peer_data) do
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

  @spec parse_bitfield(binary(), [integer()], integer()) :: [integer()]
  def parse_bitfield(<<bit::size(1), rest::bytes>>, queue, acc) do
    if bit == 1 do
      parse_bitfield(rest, [acc | queue], acc + 1)
    else
      parse_bitfield(rest, queue, acc + 1)
    end
  end

  def parse_bitfield(_, queue, _acc) do
    queue
  end

  @spec send_message(PeerData.state(), PeerData.t()) :: PeerData.t()
  def send_message(:me_choke_it_interest, peer_data) do
    msg1 = PeerProtocol.encode(:keep_alive)

    case @torrent_impl.get_next_piece_index(
           peer_data.torrent_id,
           Map.keys(peer_data.piece_table)
         ) do
      {:ok, next_piece_index} ->
        next_sub_piece_index = 0

        msg2 =
          PeerProtocol.encode(:request, next_piece_index, next_sub_piece_index)

        @tcp_conn_impl.send(peer_data.socket, msg1 <> msg2)

        Logger.debug(fn ->
          "#{peer_data.name} has sent Request MSG: #{inspect(msg2)}"
        end)

      {:error, msg} ->
        Logger.error(
          "#{peer_data.data.name} was not able to get a available piece: #{msg}"
        )
    end

    peer_data
  end

  def send_message(:me_interest_it_choke, peer_data) do
    _msg1 = PeerProtocol.encode(:keep_alive)
    peer_data
  end

  def send_message(:we_interest, peer_data) do
    # Cant send data yet but switch between request/desired queues
    msg1 = PeerProtocol.encode(:keep_alive)
    # msg3 = unless Application.get_env(:bittorrent_client, :upload_check) do
    #  <<>>
    # else
    #  PeerProtocol.encode(:choke)
    # end

    case @torrent_impl.get_next_piece_index(
           peer_data.torrent_id,
           Map.keys(peer_data.piece_table)
         ) do
      {:ok, next_piece_index} ->
        next_sub_piece_index = 0

        msg2 =
          PeerProtocol.encode(:request, next_piece_index, next_sub_piece_index)

        @tcp_conn_impl.send(peer_data.socket, msg1 <> msg2)

        Logger.debug(fn ->
          "#{peer_data.name} has sent Request MSG: #{inspect(msg2)}"
        end)

      {:error, msg} ->
        Logger.error(
          "#{peer_data.data.name} was not able to get a available piece: #{msg}"
        )
    end

    peer_data
  end

  def send_message(:we_choke, peer_data) do
    {_status, _lst} =
      @torrent_impl.get_completed_piece_list(peer_data.torrent_id)

    #    current_bitfield = BitUtility.create_empty_bitfield()
    #    bitfield_msg = PeerProtocol.encode(:bitfield,)
    bitfield = <<>>

    interest_msg =
      case peer_data.piece_table do
        %{} ->
          Logger.debug(fn -> "#{peer_data.name} has nothing of interest" end)
          PeerProtocol.encode(:not_interested)

        _ ->
          Logger.debug(fn -> "#{peer_data.name} has something of interest" end)
          PeerProtocol.encode(:interested)
      end

    @tcp_conn_impl.send(peer_data.socket, bitfield <> interest_msg)
    peer_data
  end

  def send_message(_, peer_data) do
    Logger.debug(fn ->
      "#{peer_data.name} is in #{inspect(peer_data.state)} state"
    end)

    peer_data
  end
end
