defmodule BittorrentClient.Cache.Supervisor do
  @moduledoc """
  """
  use Supervisor
  require Logger
  @config_cache Application.get_env(:bittorrent_client, :config_cache)
  @torrent_cache Application.get_env(:bittorrent_client, :torrent_cache)

  def start_link do
    Logger.info("Starting Cache Supervisor")
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    supervise(
      [worker(@config_cache, [], restart: :permanant),
        worker(@torrent_cache, [], restart: :permanant)
      ],
      strategy: :one_for_one
    )
  end
end
