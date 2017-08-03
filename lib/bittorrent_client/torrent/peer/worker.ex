defmodule BittorrentClient.Torrent.Peer.Worker do
  @moduledoc """
  Peer worker to handle peer connections
  https://wiki.theory.org/index.php/BitTorrentSpecification#Peer_wire_protocol_.28TCP.29
  """
  use GenServer
  require Logger
  alias BittorrentClient.Torrent.Peer.Data, as: PeerData
  alias BittorrentClient.Torrent.Peer.Supervisor, as: PeerSupervisor
  alias BittorrentClient.Torrent.Peer.Protocol, as: PeerProtocol

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
      am_choking: 1,
      am_interested: 0,
      peer_choking: 0,
      peer_interested: 0,
      handshake_check: false,
      metainfo: metainfo,
      timer: nil,
      name: name
    }
    GenServer.start_link(
      __MODULE__,
      {peer_data},
      name: {:global, {:btc_peerworker, name}}
    )
  end

  def init({peer_data})do
    timer = :erlang.start_timer(peer_data.interval, self(), :send_message)
    Logger.info fn -> "Starting peer worker for #{peer_data.name}" end
    sock = connect(peer_data.peer_ip, peer_data.peer_port)
    msg = PeerProtocol.encode(:handshake, <<0::size(64)>>, peer_data.info_hash, peer_data.peer_id)
    send_handshake(sock, msg)
    temp = Map.merge(peer_data, %PeerData{socket: sock})
    {:ok, {temp}}
  end

  # these handle_info calls come from the socket for attention
  def handle_info({:error, reason}, peer_data) do
    Logger.error fn -> "#{peer_data.name} has come across and error" end
    # terminate genserver gracefully?
    {:noreply, peer_data}
  end

  # Bread and butter
  def handle_info({:tcp, _socket, msg}, peer_data) do
    Logger.debug fn -> "Basic socket event:  msg -> #{inspect msg} peer_data -> #{inspect peer_data}" end
    msgs = PeerProtocol.decode(msg)
    # {:noreply, List.foldl(msgs, peer_data, fn(msg, peer_data)-> handle_message(msgs, socket, peer_data) end)}
    {:noreply, peer_data}
  end

  # Extra use cases
  def handle_info({:tcp_passive, socket}, peer_data) do
    :inet.setopts(socket, [active: 1])
    {:noreply, peer_data}
  end

  def handle_info({:tcp_closed, socket}, peer_data) do
    Logger.info fn -> "#{peer_data.name} has closed socket, should terminate" end
    # Gracefully stop this peer process OR get a new peer
    {:noreply, peer_data}
  end

  def handle_info({:timeout, reason, :send_message}, peer_data) do
    Logger.error fn -> "#{peer_data.name} took too long: #{reason}" end
    {:noreply, peer_data}
  end

  def whereis(pworker_id) do
    :global.whereis_name({:btc_peerworker, pworker_id})
  end

  # Utility
  defp ip_to_str({f,s,t,fr}) do
    "#{f}.#{s}.#{t}.#{fr}"
  end

  defp send_handshake(socket, msg) do
    :gen_tcp.send(socket, msg)
  end

  defp connect(ip, port) do
    {:ok, sock} = :gen_tcp.connect(ip, port, [:binary, active: 1], 2_000)
    Logger.debug fn -> "#{ip_to_str(ip)}:#{port} is connected}" end
    sock
  end

  defp handle_message(msg, socket, peer_data) do
    # hand types
    state = {
      peer_data.handshake_check,
      peer_data.am_choking,
      peer_data.am_interested,
      peer_data.peer_choking,
      peer_data.peer_interested
    }
    Logger.debug fn -> "#{peer_data.name}: #{inspect msg}" end
    peer_data
  end
end
