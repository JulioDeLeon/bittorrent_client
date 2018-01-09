defmodule BittorrentClient.Server.Supervisor do
  @moduledoc """
  ServerSupervisor supervises BittorrentClient Server
  """
  use Supervisor
  alias BittorrentClient.Logger.Factory, as: LoggerFactory
  alias BittorrentClient.Logger.JDLogger, as: JDLogger

  @logger LoggerFactory.create_logger(__MODULE__)
  @server_impl Application.get_env(:bittorrent_client, :server_impl)

  def start_link(name) do
    JDLogger.info(@logger, "Starting Server Supervisor")
    Supervisor.start_link(__MODULE__, [name])
  end

  def init([name]) do
    children = [
      worker(@server_impl, ["./", name], id: {:server, name})
    ]

    supervise(children, strategy: :one_for_one)
  end
end
