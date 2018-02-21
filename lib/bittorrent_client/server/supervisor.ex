defmodule BittorrentClient.Server.Supervisor do
  @moduledoc """
  ServerSupervisor supervises BittorrentClient Server
  """
  use Supervisor
  require Logger
  @server_impl Application.get_env(:bittorrent_client, :server_impl)

  def start_link(name) do
    Logger.info("Starting Server Supervisor")
    Supervisor.start_link(__MODULE__, [name])
  end

  def init([name]) do
    children = [
      worker(@server_impl, ["./", name], id: {:server, name})
    ]

    supervise(children, strategy: :one_for_one)
  end
end
