defmodule BittorrentClient.Torrent.Peer.Worker do
  @moduledoc """
  Peer worker to handle peer connections
  """
  use GenServer
  require Logger

  def start_link({torrent_id, filename, tracker_id, interval, ip, port}) do
    Logger.info fn -> "Starting peer worker for #{filename}->#{ip}:#{port}" end
    # create tcp socket connectiion

    GenServer.start_link(
      __MODULE__,
      {},
      name: {:global, {:btc_peerworker, "#{filename}_#{ip}_#{port}"}})
  end

  def init() do
    {:ok, {}}
  end

  def start_peer_handshake() do
  end

  def start_peer_leeching() do
  end


end
