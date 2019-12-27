defmodule BittorrentClient.Cache.Supervisor do
  @moduledoc """
  Supervisor implementation for cache process
  """
  use Supervisor
  require Logger
  @config_cache_impl Application.get_env(:bittorrent_client, :config_cache_impl)
  @config_cache_name Application.get_env(:bittorrent_client, :config_cache_name)
  @config_cache_opts Application.get_env(:bittorrent_client, :config_cache_opts)
  @torrent_cache_impl Application.get_env(
                        :bittorrent_client,
                        :torrent_cache_impl
                      )
  @torrent_cache_name Application.get_env(
                        :bittorrent_client,
                        :torrent_cache_name
                      )

  def start_link do
    Logger.info("Starting Cache Supervisor")
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    children = [
      %{
        id: @config_cache_name,
        start:
          {@config_cache_impl, :start_link,
           [@config_cache_name, @config_cache_opts]},
        restart: :permanent,
        shutdown: :infinity
      },
      %{
        id: @torrent_cache_name,
        start:
          {@torrent_cache_impl, :start_link,
           [@torrent_cache_name, [
               {:attributes, [:id, :filename, :index, :peers, :status, :buffer]},
               {:disc_only_copies, [node()]}
             ]]},
        restart: :permanent,
        shutdown: :infinity
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
