defmodule BittorrentClient.Torrent.Peer.Supervisor do
  @moduledoc """
  Peer supervisor which is created when a new torrent is created to mange peer connections
  """
  use Supervisor
  require Logger
  alias BittorrentClient.Torrent.Peer.Worker, as: PeerWorker

  def start_link do
    Logger.info fn -> "Starting Peer supervisor" end
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    supervise([worker(PeerWorker, [])],
      strategy: :simple_one_for_one)
  end

  def start_child({metainfo, torrent_id, info_hash, filename, tracker_id, interval, ip, port}) do
    Logger.info fn -> "Starting peer connection for #{torrent_id}" end
    # This also looks like this can be shipped at a list
    Supervisor.start_child(__MODULE__, [{metainfo,
                                         torrent_id,
                                         info_hash,
                                         filename,
                                         tracker_id,
                                         interval,
                                         ip,
                                         port
                                        }])
  end

  def terminate_child(peer_pid) do
    Supervisor.terminate_child(__MODULE__, peer_pid)
  end
end
