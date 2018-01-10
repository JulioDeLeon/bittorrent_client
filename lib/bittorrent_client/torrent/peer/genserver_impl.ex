defmodule BittorrentClient.Torrent.Peer.GenServerImpl do
  @moduledoc """
  Peer worker to handle peer connections
  https://wiki.theory.org/index.php/BitTorrentSpecification#Peer_wire_protocol_.28TCP.29
  """
  @behaviour BittorrentClient.Torrent.Peer
  use GenServer
  alias BittorrentClient.Torrent.Peer.Data, as: PeerData
  alias BittorrentClient.Torrent.Peer.Protocol, as: PeerProtocol
  alias BittorrentClient.Logger.Factory, as: LoggerFactory
  alias BittorrentClient.Logger.JDLogger, as: JDLogger

  @torrent_impl Application.get_env(:bittorrent_client, :torrent_impl)
  @logger LoggerFactory.create_logger(__MODULE__)

  def start_link({metainfo, torrent_id, info_hash, filename, interval, ip, port}) do
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
      piece_index: 0,
      sub_piece_index: 0,
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
    sock = connect(peer_data.peer_ip, peer_data.peer_port)
    msg = PeerProtocol.encode(:handshake, <<0::size(64)>>,
      peer_data.info_hash, peer_data.peer_id)
    send_handshake(sock, msg)
    {:ok, {%PeerData{peer_data | timer: timer, socket: sock}}}
  end

  # these handle_info calls come from the socket for attention
  def handle_info({:error, reason}, peer_data) do
    JDLogger.error(@logger, "#{peer_data.name} has come across and error: #{reason}")
    # terminate genserver gracefully?
    {:noreply, peer_data}
  end

  # Bread and butter
  def handle_info({:timeout, timer, :send_message}, state) do
    # this should look at the state of the message to determine what to send
    # to peer. the timer sends a signal to the peer handle when it is time to
    # send over a message.
    # JDLogger.debug(@logger, "What is this: #{inspect peer_data}")
    {peer_data} = state
    :erlang.cancel_timer(timer)
    ret = fn new_state ->
      timer = :erlang.start_timer(peer_data.interval, self(), :send_message)
      {:noreply, {%PeerData{new_state | timer: timer}}}
    end
    # JDLogger.debug(@logger, "#{peer_data.name} has received a timer event")
    socket = peer_data.socket
    case peer_data.state do
      # No sharing is happening
      :we_choke ->
        msg = PeerProtocol.encode(:interested)
        :gen_tcp.send(socket, msg)
        JDLogger.debug(@logger, "#{peer_data.name} sent interested msg")
        ret.(peer_data)

      # Client does not give, Client request data from peer
      :me_choke_it_interest ->
        msg1 = PeerProtocol.encode(:keep_alive)
        case @torrent_impl.get_next_piece_index(peer_data.torrent_id, Map.keys(peer_data.piece_table)) do
          {:ok, next_piece_index} ->
            next_sub_piece_index = 0
            msg2 = PeerProtocol.encode(:request, next_piece_index, next_sub_piece_index)
            :gen_tcp.send(peer_data.socket, msg1 <> msg2)
            JDLogger.debug(@logger, "#{peer_data.name} has sent Request MSG: #{inspect msg2}")
          {:error, msg} ->
            JDLogger.error(@logger, "#{peer_data.data.name} was not able to get a available piece: #{msg}")
        end
        ret.(peer_data)

      # Peer is interest in data client has, client is not requesting data from peer
      :me_interest_it_choke ->
        # Cant send data yet
        ret.(peer_data)

      # Client and Peer are sending data back and forth
      :we_interest ->
        # Cant send data yet but switch between request/desired queues
        msg1 = PeerProtocol.encode(:keep_alive)
        case @torrent_impl.get_next_piece_index(peer_data.torrent_id, Map.keys(peer_data.piece_table)) do
          {:ok, next_piece_index} ->
            next_sub_piece_index = 0
            msg2 = PeerProtocol.encode(:request, next_piece_index, next_sub_piece_index)
            :gen_tcp.send(peer_data.socket, msg1 <> msg2)
            JDLogger.debug(@logger, "#{peer_data.name} has sent Request MSG: #{inspect msg2}")
          {:error, msg} ->
            JDLogger.error(@logger, "#{peer_data.data.name} was not able to get a available piece: #{msg}")
        end
        ret.(peer_data)
      _ ->
        JDLogger.debug(@logger, "#{peer_data.name} is in #{inspect peer_data.state} state")
        ret.(peer_data)
    end
  end

  def handle_info({:tcp, socket, msg}, peer_data) do
    # this should handle what ever msgs that received from the peer
    # the tcp socket alerts the peer handler when there are messages to be read
    # JDLogger.debug(@logger, "Basic socket event:  msg -> #{inspect msg} peer_data -> #{inspect peer_data}")
    {msgs, _} = PeerProtocol.decode(msg)
    {a_pd} = peer_data
    # JDLogger.debug(@logger, "Messages #{inspect msgs} for #{inspect peer_data}")
    ret = loop_msgs(msgs, socket, a_pd)
    # JDLogger.debug(@logger, "Returning this: #{inspect ret}")
    {:noreply, {ret}}
  end

  # Extra use cases
  def handle_info({:tcp_passive, socket}, peer_data) do
    :inet.setopts(socket, [active: 1])
    {:noreply, peer_data}
  end

  def handle_info({:tcp_closed, _socket}, {peer_data}) do
    JDLogger.info(@logger, "#{peer_data.name} has closed socket, should terminate")
    # Gracefully stop this peer process OR get a new peer
    {:noreply, {peer_data}}
  end

  def whereis(pworker_id) do
    :global.whereis_name({:btc_peerworker, pworker_id})
  end

  # Utility
  defp handle_message(msg, _socket, peer_data) do
    # JDLogger.debug(@logger, "Within handle_message: #{inspect peer_data}")
    unless msg.type == :keep_alive do
      JDLogger.debug(@logger, "Stay-Alive: #{peer_data.name}")
    end
    peer_state = peer_data.state
    case msg.type do
      :handshake ->
        if peer_data.handshake_check == false do
          # TODO: check the recieved info hash?
          JDLogger.debug(@logger, "Handshake MSG: #{peer_data.name}")
          %PeerData{peer_data | state: :we_choke , handshake_check: true}
        else
          peer_data
        end
      :choke -> # Stop leaching
        JDLogger.debug(@logger, "Choke MSG: #{peer_data.name}")
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
        JDLogger.debug(@logger, "Unchoke MSG: #{peer_data.name}")
        state = case peer_state do
                  :we_choke ->
                    :me_choke_it_interest
                  :me_interest_it_choke ->
                    :we_interest
                end
        %PeerData{peer_data | state: state}
      :interested ->
        # TODO Start seeding
        JDLogger.debug(@logger, "Interested MSG: #{peer_data.name}")
        JDLogger.debug(@logger, "Cannot seed yet so not changing peer state")
        # have state changing code similar to choke/unchoke
        peer_data
      :not_interest ->
        # TODO Stop seeding
        JDLogger.debug(@logger, "Not_interested MSG: #{peer_data.name}")
        JDLogger.debug(@logger, "Not seeding yet so no need to stop seeding")
        # have state changing code similar to choke/unchoke
        peer_data
      :have ->
        # Peer lets client know which pieces it has
        # Could send message back to parent torrent process to log/add to known pieces
        # TODO make this info useful
        # Send the message payload back to the torrent process to put together to track
        JDLogger.debug(@logger, "Have MSG: #{peer_data.name}")
        {status, _} = @torrent_impl.add_new_piece_index(peer_data.torrent_id, peer_data.peer_id, msg.piece_index)
        case status do
          :ok ->
            JDLogger.debug(@logger, "#{peer_data.name} successfully added #{msg.piece_index} to it's table.")
            %PeerData{peer_data | piece_table: Map.merge(peer_data.piece_table, %{msg.piece_index => :found})}
          _ -> peer_data
        end
      :bitfield ->
        # Similar to :have but more compact
        # TODO make this info useful
        # Again, send the payload back to the torrent process to process and track
        JDLogger.debug(@logger, "Bitfield MSG: #{peer_data.name}")
        new_table = parse_bitfield(msg.bitfield, peer_data.piece_table, 0)
        {status, valid_indexes} = @torrent_impl.add_multi_pieces(peer_data.torrent_id, peer_data.peer_id, Map.keys(new_table))
        case status do
          :ok ->
            JDLogger.debug(@logger, "#{peer_data.name} successfully added #{inspect(valid_indexes)} to it's table.")
            %PeerData{peer_data | piece_table: Map.split(new_table, valid_indexes)}
          _ -> peer_data
        end
      :piece ->
        # TODO piece
        # Send the piece information back to the torrent process to put the file together
        JDLogger.debug(@logger, "Piece MSG: #{peer_data.name}")
        peer_data
      :cancel ->
        # TODO kills this peer handling process gracefull
        JDLogger.debug(@logger, "Cancel MSG: #{peer_data.name}")
        peer_data
      :port ->
        # TODO handle port change
        JDLogger.debug(@logger, "Port MSG: #{peer_data.name}")
        peer_data
     _ ->
        unless msg.type == :keep_alive do
          JDLogger.error(@logger, "#{peer_state.name} could not handle this message: #{inspect msg}")
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
        JDLogger.debug(@logger, "#{ip_to_str(ip)}:#{port} is connected")
        sock
    end
  end

  defp parse_bitfield(<<bit::size(1), rest::bytes>>, queue, acc) do
    if bit  == 1 do
      parse_bitfield(rest, Map.merge(queue, %{acc => :found}), (acc + 1))
    else
      parse_bitfield(rest, queue, (acc + 1))
    end
  end

  defp parse_bitfield(_, queue, _acc) do
    queue
  end
end
