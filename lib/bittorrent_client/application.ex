defmodule BittorrentClient.Application do
  @moduledoc """
  Application entry point for Bittorrent Client
  """
  use Application
  alias BittorrentClient.Cache.Supervisor, as: BTCCacheSupervisor
  alias BittorrentClient.Peer.Supervisor, as: BTCPeerSupervisor
  alias BittorrentClient.Server.Supervisor, as: BTCServerSupervisor
  alias BittorrentClient.Supervisor, as: BTCSupervisor
  alias BittorrentClient.Torrent.Supervisor, as: BTCTorrentSupervisor
  alias BittorrentClientWeb.Endpoint, as: BTCEndpoint

  @file_destination Application.get_env(:bittorrent_client, :file_destination)
  @server_name Application.get_env(:bittorrent_client, :server_name)
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    case initialize_env() do
      {:error, err} ->
        {:error, err}

      :ok ->
        startup()
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    BTCEndpoint.config_change(changed, removed)
    :ok
  end

  # Initialize Mnesia on startup
  @spec initialize_env :: :ok | {:error, any()}
  defp initialize_env do
    :mnesia.create_schema([node()])
    :mnesia.start()
  end

  defp startup do
    import Supervisor.Spec
    # Define workers and child supervisors to be supervised
    children = [
      # Start the Ecto repository
      # supervisor(BittorrentClient.Repo, []),
      # Start the endpoint when the application starts
      supervisor(BTCEndpoint, []),
      # Start your own worker by calling: BittorrentClient.Worker.start_link(arg1, arg2, arg3)
      # worker(BittorrentClient.Worker, [arg1, arg2, arg3]),
      supervisor(BTCServerSupervisor, [
        @file_destination,
        @server_name
      ]),
      supervisor(BTCTorrentSupervisor, []),
      supervisor(BTCPeerSupervisor, []),
      supervisor(BTCCacheSupervisor, [])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BTCSupervisor]
    Supervisor.start_link(children, opts)
  end
end
