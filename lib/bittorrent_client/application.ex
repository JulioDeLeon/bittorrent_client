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

  @file_destination Application.compile_env(
                      :bittorrent_client,
                      :file_destination
                    )
  @server_name Application.compile_env(:bittorrent_client, :server_name)
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
    # Define workers and child supervisors to be supervised
    children = [
      {Phoenix.PubSub, name: BittorrentClient.PubSub},
      BTCEndpoint,
      %{
        id: BTCServerSupervisor,
        start:
          {BTCServerSupervisor, :start_link, [@file_destination, @server_name]},
        type: :supervisor
      },
      %{
        id: BTCTorrentSupervisor,
        start: {BTCTorrentSupervisor, :start_link, []},
        type: :supervisor
      },
      %{
        id: BTCPeerSupervisor,
        start: {BTCPeerSupervisor, :start_link, []},
        type: :supervisor
      },
      %{
        id: BTCCacheSupervisor,
        start: {BTCCacheSupervisor, :start_link, []},
        type: :supervisor
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BTCSupervisor]
    Supervisor.start_link(children, opts)
  end
end
