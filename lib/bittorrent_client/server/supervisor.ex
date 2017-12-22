defmodule BittorrentClient.Server.Supervisor do
  @moduledoc """
  ServerSupervisor supervises BittorrentClient Server
  """
  use Supervisor
  alias BittorrentClient.Server.Worker, as: Server
  alias BittorrentClient.Logger.Factory, as: LoggerFactory
  alias BittorrentClient.Logger.JDLogger, as: JDLogger

  @logger LoggerFactory.create_logger(__MODULE__)

  def start_link(name) do
    JDLogger.info(@logger, "Starting Server Supervisor")
    Supervisor.start_link(__MODULE__, [name])
  end

  def init([name]) do
    children = [
      worker(Server, ["./", name], id: {:server, name})
    ]

    supervise(children, strategy: :one_for_one)
  end
end
