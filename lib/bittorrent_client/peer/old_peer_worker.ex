defmodule BittorrentClient.Peer.OldImpl do
  @moduledoc """
  Peer worker to handle peer connections
  https://wiki.theory.org/index.php/BitTorrentSpecification#Peer_wire_protocol_.28TCP.29
  """
  use GenServer
  require Logger
  alias BittorrentClient.Torrent.Peer.Data, as: PeerData
  alias BittorrentClient.Torrent.Peer.Protocol, as: PeerProtocol
  alias BittorrentClient.Torrent.Worker, as: TorrentWorker

  def start_link({metainfo, torrent_id, info_hash, filename, tracker_id, interval, ip, port}) do
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
      state: :we_choke,
      metainfo: metainfo,
      timer: nil,
      tracker_id: tracker_id,
      piece_index: 0,
      sub_piece_index: 0,
      piece_queue: %{},
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
    Logger.info fn -> "Starting peer worker for #{peer_data.name}" end
    sock = connect(peer_data.peer_ip, peer_data.peer_port)
    msg = PeerProtocol.encode(:handshake, <<0::size(64)>>,
      peer_data.info_hash, peer_data.peer_id)
    send_handshake(sock, msg)
    {:ok, {%PeerData{peer_data | timer: timer, socket: sock}}}
  end

  # these handle_info calls come from the socket for attention
  def handle_info({:error, reason}, peer_data) do
    Logger.error fn -> "#{peer_data.name} has come across and error: #{reason}" end
    # terminate genserver gracefully?
    {:noreply, peer_data}
  end

  # Bread and butter
  def handle_info({:timeout, timer, :send_message}, state) do
    # this should look at the state of the message to determine what to send
    # to peer. the timer sends a signal to the peer handle when it is time to
    # send over a message.
    # Logger.debug fn -> "What is this: #{inspect peer_data}" end
    {peer_data} = state
    :erlang.cancel_timer(timer)
    ret = fn  ->
      timer = :erlang.start_timer(peer_data.interval, self(), :send_message)
      {:noreply, {%PeerData{peer_data | timer: timer}}}
    end
    # Logger.debug fn -> "#{peer_data.name} has received a timer event" end
    socket = peer_data.socket
    case peer_data.state do
      :we_choke ->
        msg = PeerProtocol.encode(:interested)
        :gen_tcp.send(socket, msg)
        Logger.debug fn -> "#{peer_data.name} sent interested msg" end
        ret.()
      :me_choke_it_interest ->
        msg1 = PeerProtocol.encode(:keep_alive)
        # :gen_tcp.send(socket, msg)
        # Logger.debug fn -> "#{peer_data.name} sent keep-alive msg" end

        next_piece_index = TorrentWorker.get_next_piece_index(peer_data.torrent_id)
        next_sub_piece_index = 0
        msg2 = PeerProtocol.encode(:request, next_piece_index, next_sub_piece_index)
        :gen_tcp.send(peer_data.socket, msg1 <> msg2)
        Logger.debug fn -> "#{peer_data.name} has sent Request MSG: #{inspect msg2}"end
        ret.()
      :me_interest_it_choke ->
        # Cant send data yet
        ret.()
      :we_interest ->
        # Cant send data yet but switch between request/desired queues
        next_piece_index = TorrentWorker.get_next_piece_index(peer_data.torrent_id)
        next_sub_piece_index = 0
        msg = PeerProtocol.encode(:request, next_piece_index, next_sub_piece_index)
        :gen_tcp.send(peer_data.socket, msg)
        Logger.debug fn -> "#{peer_data.name} has sent Request MSG: #{inspect msg}"end
        ret.()
      _ ->
        Logger.debug fn -> "#{peer_data.name} is in #{inspect peer_data.state} state" end
        ret.()
    end
  end

  def handle_info({:tcp, socket, msg}, peer_data) do
    # this should handle what ever msgs that received from the peer
    # the tcp socket alerts the peer handler when there are messages to be read
    # Logger.debug fn -> "Basic socket event:  msg -> #{inspect msg} peer_data -> #{inspect peer_data}" end
    {msgs, _} = PeerProtocol.decode(msg)
    {a_pd} = peer_data
    # Logger.debug fn -> "Messages #{inspect msgs} for #{inspect peer_data}" end
    ret = loop_msgs(msgs, socket, a_pd)
    # Logger.debug fn -> "Returning this: #{inspect ret}" end
    {:noreply, {ret}}
  end

  # Extra use cases
  def handle_info({:tcp_passive, socket}, peer_data) do
    :inet.setopts(socket, [active: 1])
    {:noreply, peer_data}
  end

  def handle_info({:tcp_closed, _socket}, {peer_data}) do
    Logger.info fn -> "#{peer_data.name} has closed socket, should terminate" end
    # Gracefully stop this peer process OR get a new peer
    {:noreply, {peer_data}}
  end

  def whereis(pworker_id) do
    :global.whereis_name({:btc_peerworker, pworker_id})
  end

  # Utility
  defp handle_message(msg, _socket, peer_data) do
    # Logger.debug fn -> "Within handle_message: #{inspect peer_data}" end
    unless msg.type == :keep_alive do
      Logger.debug fn -> "Stay-Alive: #{peer_data.name}" end
    end
    peer_state = peer_data.state
    case msg.type do
      :handshake ->
        if peer_data.handshake_check == false do
          # TODO: check the recieved info hash?
          Logger.debug fn -> "Handshake MSG: #{peer_data.name}" end
          %PeerData{peer_data | state: :we_choke , handshake_check: true}
        else
          peer_data
        end
      :choke -> # Stop leaching
        Logger.debug fn -> "Choke MSG: #{peer_data.name}" end
        case peer_state do
          :we_interest ->
            %PeerData{peer_data | state: :me_choke_it_interest}
          :me_interest_it_choke ->
            %PeerData{peer_data | state: :we_choke}
          _ ->
            peer_data
        end
      :unchoke ->
        # Start/Continue leaching
        Logger.debug fn -> "Unchoke MSG: #{peer_data.name}" end
        state = case peer_state do
                  :we_choke ->
                    :me_choke_it_interest
                  :me_interest_it_choke ->
                    :we_interest
                end
        %PeerData{peer_data | state: state}
      :interested ->
        # TODO Start seeding
        Logger.debug fn -> "Interested MSG: #{peer_data.name}" end
        peer_data
      :not_interest ->
        # TODO Stop seeding
        Logger.debug fn -> "Not_interested MSG: #{peer_data.name}" end
        peer_data
      :have ->
        # Peer lets client know which pieces it has
        # Could send message back to parent torrent process to log/add to known pieces
        # TODO make this info useful
        # Send the message payload back to the torrent process to put together to track
        Logger.debug fn -> "Have MSG: #{peer_data.name}" end
        %PeerData{peer_data | piece_queue: Map.merge(peer_data.piece_queue, %{msg.piece_index => :intial})}
      :bitfield ->
        # Similar to :have but more compact
        # TODO make this info useful
        # Again, send the payload back to the torrent process to process and track
        Logger.debug fn -> "Bitfield MSG: #{peer_data.name}" end
        pqueue = parse_bitfield(msg.bitfield, peer_data.piece_queue, 0)
        # Logger.debug fn -> "BF has: #{inspect pqueue}" end
        %PeerData{peer_data | piece_queue: pqueue}
      :piece ->
        # TODO piece
        # Send the piece information back to the torrent process to put the file together
        Logger.debug fn -> "Piece MSG: #{peer_data.name}" end
        peer_data
      :cancel ->
        # TODO kills this peer handling process gracefull
        Logger.debug fn -> "Cancel MSG: #{peer_data.name}" end
        peer_data
      :port ->
        # TODO handle port change
        Logger.debug fn -> "Port MSG: #{peer_data.name}" end
        peer_data
     _ ->
        unless msg.type == :keep_alive do
          Logger.error fn -> "#{peer_state.name} could not handle this message: #{inspect msg}" end
          peer_data
        end
    end
  end

  defp loop_msgs([msg | msgs], socket, peer_data) do
    state = handle_message(msg, socket, peer_data)
    loop_msgs(msgs, socket, state)
  end

  defp loop_msgs(_, _, peer_data) do
    peer_data
  end

  defp ip_to_str({f, s, t, fr}) do
    "#{f}.#{s}.#{t}.#{fr}"
  end

  defp send_handshake(socket, msg) do
    :gen_tcp.send(socket, msg)
  end

  defp connect(ip, port) do
    {status, sock} = :gen_tcp.connect(ip, port, [:binary, active: 1], 2_000)
    case status do
      :error ->
        raise "#{ip_to_str(ip)}:#{port} could not connect"
      :ok ->
        Logger.debug fn -> "#{ip_to_str(ip)}:#{port} is connected" end
        sock
    end
  end

  defp parse_bitfield(<<bit::size(1), rest::bytes>>, queue, acc) do
    if bit  == 1 do
      parse_bitfield(rest, Map.merge(queue, %{acc => :initial}), (acc + 1))
    else
      parse_bitfield(rest, queue, (acc + 1))
    end
  end

  defp parse_bitfield(_, queue, _acc) do
    queue
  end
end
