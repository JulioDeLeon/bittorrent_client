defmodule BittorrentClient.Peer.Supervisor do
  @moduledoc """
  Peer supervisor which is created when a new torrent is created to mange peer connections
  """
  use Supervisor
  require Logger

  @peer_impl Application.get_env(:bittorrent_client, :peer_impl)

  def start_link do
    Logger.info("Starting Peer supervisor")
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    supervise(
      [worker(@peer_impl, [], restart: :temporary)],
      strategy: :simple_one_for_one
    )
  end

  def start_child(
        {metainfo, torrent_id, info_hash, filename, interval, ip, port}
      ) do
    Logger.debug("Starting peer connection for #{torrent_id}")
    # This also looks like this can be shipped at a list
    Supervisor.start_child(__MODULE__, [
      {metainfo, torrent_id, info_hash, filename, interval, ip, port}
    ])
  end

  def terminate_child(peer_id) do
    pid = @peer_impl.whereis(peer_id)

    case pid do
      :undefined ->
        msg = "invalid peer id was given: #{peer_id}"
        Logger.error(msg)
        {:error, msg}

      _ ->
        Supervisor.terminate_child(__MODULE__, peer_id)
    end
  end
end
