defmodule BittorrentClient.Application do
  use Application

  @file_destination Application.get_env(:bittorrent_client, :file_destination)
  @server_name Application.get_env(:bittorrent_client, :server_name)
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec
    # Define workers and child supervisors to be supervised
    children = [
      # Start the Ecto repository
      supervisor(BittorrentClient.Repo, []),
      # Start the endpoint when the application starts
      supervisor(BittorrentClientWeb.Endpoint, []),
      # Start your own worker by calling: BittorrentClient.Worker.start_link(arg1, arg2, arg3)
      # worker(BittorrentClient.Worker, [arg1, arg2, arg3]),
      supervisor(BittorrentClient.Server.Supervisor, [
        @file_destination,
        @server_name
      ]),
      supervisor(BittorrentClient.Torrent.Supervisor, []),
      supervisor(BittorrentClient.Peer.Supervisor, [])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BittorrentClient.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    BittorrentClientWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
