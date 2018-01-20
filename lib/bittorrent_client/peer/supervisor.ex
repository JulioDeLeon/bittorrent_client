defmodule BittorrentClient.Peer.Supervisor do
  @moduledoc """
  Peer supervisor which is created when a new torrent is created to mange peer connections
  """
  use Supervisor
  alias BittorrentClient.Logger.Factory, as: LoggerFactory
  alias BittorrentClient.Logger.JDLogger, as: JDLogger

  @peer_impl Application.get_env(:bittorrent_client, :peer_impl)
  @logger LoggerFactory.create_logger(__MODULE__)

  def start_link do
    JDLogger.info(@logger, "Starting Peer supervisor")
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    supervise(
      [worker(@peer_impl, [], restart: :temporary)],
      strategy: :simple_one_for_one,
    )
  end

  def start_child(
        {metainfo, torrent_id, info_hash, filename, interval, ip, port}
      ) do
    JDLogger.info(@logger, "Starting peer connection for #{torrent_id}")
    # This also looks like this can be shipped at a list
    Supervisor.start_child(__MODULE__, [
      {metainfo, torrent_id, info_hash, filename, interval, ip, port}
    ])
  end

  def terminate_child(peer_pid) do
    Supervisor.terminate_child(__MODULE__, peer_pid)
  end
end
