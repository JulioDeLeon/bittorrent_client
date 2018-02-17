defmodule BittorrentClient.Peer.GenServerImpl do
  @moduledoc """
  Peer worker to handle peer connections
  https://wiki.theory.org/index.php/BitTorrentSpecification#Peer_wire_protocol_.28TCP.29
  """
  @behaviour BittorrentClient.Peer
  use GenServer
  require Bitwise
  alias BittorrentClient.Peer.Data, as: PeerData
  alias BittorrentClient.Peer.Protocol, as: PeerProtocol
  alias BittorrentClient.Logger.Factory, as: LoggerFactory
  alias BittorrentClient.Logger.JDLogger, as: JDLogger
  alias BittorrentClient.Peer.Supervisor, as: PeerSupervisor

  @torrent_impl Application.get_env(:bittorrent_client, :torrent_impl)
  @tcp_conn_impl Application.get_env(:bittorrent_client, :tcp_conn_impl)
  @logger LoggerFactory.create_logger(__MODULE__)

  def start_link(
        {metainfo, torrent_id, info_hash, filename, interval, ip, port}
      ) do
    name = "#{torrent_id}_#{ip_to_str(ip)}_#{port}"

    peer_data = %PeerData{
      torrent_id: torrent_id,
      peer_id: Application.fetch_env!(:bittorrent_client, :peer_id),
      filename: filename,
      peer_ip: ip,
      peer_port: port,
      interval: interval,
      info_hash: info_hash,
      handshake_check: false,
      need_piece: true,
      state: :we_choke,
      metainfo: metainfo,
      timer: nil,
      piece_index: 0,
      sub_piece_index: 0,
      piece_length: metainfo.info."piece length",
      piece_table: %{},
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
    JDLogger.info(@logger, "Starting peer worker for #{peer_data.name}")
    JDLogger.debug(@logger, "Using tcp_conn_imp: #{@tcp_conn_impl}")
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
    {:ok, {%PeerData{peer_data | timer: timer, socket: sock}}}
  end

  # these handle_info calls come from the socket for attention
  def handle_info({:error, reason}, peer_data) do
    JDLogger.error(
      @logger,
      "#{peer_data.name} has come across and error: #{reason}"
    )

    # terminate genserver gracefully?
    PeerSupervisor.terminate_child(peer_data.peer_id)
    {:noreply, peer_data}
  end

  def handle_info({:timeout, timer, :send_message}, {peer_data}) do
    # this should look at the state of the message to determine what to send
    # to peer. the timer sends a signal to the peer handle when it is time to
    # send over a message.
    # JDLogger.debug(@logger, "What is this: #{inspect peer_data}")
    :erlang.cancel_timer(timer)
    new_state = send_message(peer_data.state, peer_data)
    timer = :erlang.start_timer(peer_data.interval, self(), :send_message)
    {:noreply, {%PeerData{new_state | timer: timer}}}
  end

  def handle_info({:tcp, socket, msg}, peer_data) do
    # this should handle what ever msgs that received from the peer
    # the tcp socket alerts the peer handler when there are messages to be read
    {msgs, _} = PeerProtocol.decode(msg)
    {a_pd} = peer_data

    # JDLogger.debug(@logger, "Messages #{inspect msgs} for #{inspect peer_data}")
    ret = loop_msgs(msgs, socket, a_pd)
    # JDLogger.debug(@logger, "Returning this: #{inspect ret}")
    {:noreply, {ret}}
  end

  # Extra use cases
  def handle_info({:tcp_passive, socket}, peer_data) do
    :inet.setopts(socket, active: 1)
    {:noreply, peer_data}
  end

  def handle_info({:tcp_closed, _socket}, {peer_data}) do
    JDLogger.info(
      @logger,
      "#{peer_data.name} has closed socket, should terminate"
    )

    # Gracefully stop this peer process OR get a new peer
    PeerSupervisor.terminate_child(peer_data.peer_id)
    {:noreply, {peer_data}}
  end

  def whereis(pworker_id) do
    :global.whereis_name({:btc_peerworker, pworker_id})
  end

  def handle_message(:keep_alive, _msg, _socket, peer_data) do
    JDLogger.debug(@logger, "Stay-Alive MSG: #{peer_data.name}")
    peer_data
  end

  def handle_message(:handshake, msg, _socket, peer_data) do
    # TODO: check the recieved info hash?
    expected = Map.get(peer_data, "info_hash")
    if msg != expected do
      JDLogger.error(@logger, "INFO HASH did not match #{msg} != #{expected}")
      JDLogger.error(@logger, "Not acting upon this")
    end
    JDLogger.debug(@logger, "Handshake MSG: #{peer_data.name}")
    %PeerData{peer_data | state: :we_choke, handshake_check: true}
  end


  def handle_message(:choke, _msg, _socket, peer_data) do
    JDLogger.debug(
      @logger,
      "Choke MSG: #{peer_data.name} will stop leaching data"
    )

    case peer_data.state do
      :we_interest ->
        %PeerData{peer_data | state: :me_choke_it_interest}

      :me_interest_it_choke ->
        %PeerData{peer_data | state: :we_choke}

      _ ->
        peer_data
    end
  end

  def handle_message(:unchoke, _msg, _socket, peer_data) do
    JDLogger.debug(
      @logger,
      "Unchoke MSG: #{peer_data.name} will start leaching"
    )

    # get pieces
    case peer_data.state do
      :we_choke ->
        %PeerData{peer_data | state: :me_interest_it_choke}

      :me_choke_it_interest ->
        %PeerData{peer_data | state: :we_interest}

      _ ->
        peer_data
    end
  end

  def handle_message(:interested, _msg, _socket, peer_data) do
    JDLogger.debug(
      @logger,
      "Interested MSG: #{peer_data.name} will start serving data"
    )

    case peer_data.state do
      :we_choke ->
        %PeerData{peer_data | state: :me_choke_it_interest}

      :me_interest_it_choke ->
        %PeerData{peer_data | state: :we_interest}

      _ ->
        peer_data
    end
  end

  def handle_message(:not_interested, _msg, _socket, peer_data) do
    JDLogger.debug(
      @logger,
      "Not_interested MSG: #{peer_data.name} will stop serving data"
    )

    case peer_data.state do
      :we_interest ->
        %PeerData{peer_data | state: :me_interest_it_choke}

      :me_choke_it_interest ->
        %PeerData{peer_data | state: :we_choke}

      _ ->
        peer_data
    end
  end

  def handle_message(:have, msg, _socket, peer_data) do
    JDLogger.debug(@logger, "Have MSG: #{peer_data.name}")

    {status, _} =
      @torrent_impl.add_new_piece_index(
        peer_data.torrent_id,
        peer_data.peer_id,
        msg.piece_index
      )

    case status do
      :ok ->
        JDLogger.debug(
          @logger,
          "#{peer_data.name} successfully added #{msg.piece_index} to it's table."
        )

        %PeerData{
          peer_data
          | piece_table:
              Map.merge(peer_data.piece_table, %{msg.piece_index => :found})
        }

      _ ->
        peer_data
    end
  end

  def handle_message(:bitfield, msg, _socket, peer_data) do
    JDLogger.debug(@logger, "Bitfield MSG: #{peer_data.name}")
    new_table = parse_bitfield(msg.bitfield, peer_data.piece_table, 0)

    {status, valid_indexes} =
      @torrent_impl.add_multi_pieces(
        peer_data.torrent_id,
        peer_data.peer_id,
        Map.keys(new_table)
      )

    case status do
      :ok ->
        JDLogger.debug(
          @logger,
          "#{peer_data.name} successfully added #{inspect(valid_indexes)} to it's table."
        )

        %PeerData{peer_data | piece_table: Map.split(new_table, valid_indexes)}

      _ ->
        peer_data
    end
  end

  def handle_message(:piece, msg, _socket, peer_data) do
    JDLogger.debug(@logger, "Piece MSG: #{peer_data.name}")

    if msg.piece_index == peer_data.piece_index do
      JDLogger.debug(
        @logger,
        "Piece MSG: #{peer_data.name} recieved #{inspect(msg)}"
      )

      {offset, _} = Integer.parse(msg.block_offsest)
      {length, _} = Integer.parse(msg.block_length)
      <<before::size(offset), aft>> = peer_data.piece_buffer
      new_buffer = <<before, msg.block::size(length), aft>>
      new_recieved = peer_data.bits_recieved + msg.block_length

      piece_status =
        if new_recieved == peer_data.piece_length do
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
            JDLogger.debug(
              @logger,
              "#{peer_data.name} has completed #{peer_data.piece_index}"
            )

          _ ->
            JDLogger.error(
              @logger,
              "#{peer_data.name} could not complete #{peer_data.piece_index}"
            )
        end

        new_piece_table = Map.drop(peer_data.piece_table, peer_data.piece_index)

        %PeerData{
          peer_data
          | piece_buffer: new_buffer,
            bits_recieved: new_recieved,
            piece_table: new_piece_table
        }
      else
        new_piece_table = %{peer_data.piece_data | piece_index: piece_status}

        %PeerData{
          peer_data
          | piece_buffer: new_buffer,
            bits_recieved: new_recieved,
            piece_table: new_piece_table,
            need_piece: true
        }
      end
    else
      JDLogger.debug(
        @logger,
        "Piece MSG: #{peer_data.name} has recieved the wrong piece: #{
          msg.piece_index
        }, expected: #{peer_data.piece_index}"
      )

      peer_data
    end
  end

  def handle_message(:cancel, _msg, _socket, peer_data) do
    JDLogger.debug(
      @logger,
      "Cancel MSG: #{peer_data.name}, Close port, kill process"
    )

    peer_data
  end

  def handle_message(:port, _msg, _socket, peer_data) do
    JDLogger.debug(
      @logger,
      "Port MSG: #{peer_data.name}, restablish new connect for new port"
    )

    peer_data
  end

  def handle_message(unknown_type, msg, _socket, peer_data) do
    JDLogger.error(
      @logger,
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

  def parse_bitfield(<<bit::size(1), rest::bytes>>, queue, acc) do
    if bit == 1 do
      parse_bitfield(rest, Map.merge(queue, %{acc => :found}), acc + 1)
    else
      parse_bitfield(rest, queue, acc + 1)
    end
  end

  def parse_bitfield(_, queue, _acc) do
    queue
  end

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

        JDLogger.debug(
          @logger,
          "#{peer_data.name} has sent Request MSG: #{inspect(msg2)}"
        )

      {:error, msg} ->
        JDLogger.error(
          @logger,
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

        JDLogger.debug(
          @logger,
          "#{peer_data.name} has sent Request MSG: #{inspect(msg2)}"
        )

      {:error, msg} ->
        JDLogger.error(
          @logger,
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
          JDLogger.debug(@logger, "#{peer_data.name} has nothing of interest")
          PeerProtocol.encode(:not_interested)

        _ ->
          JDLogger.debug(@logger, "#{peer_data.name} has something of interest")
          PeerProtocol.encode(:interested)
      end

    @tcp_conn_impl.send(peer_data.socket, bitfield <> interest_msg)
    peer_data
  end

  def send_message(_, peer_data) do
    JDLogger.debug(
      @logger,
      "#{peer_data.name} is in #{inspect(peer_data.state)} state"
    )

    peer_data
  end
end
