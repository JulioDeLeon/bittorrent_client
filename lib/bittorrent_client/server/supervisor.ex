defmodule BittorrentClient.Server.Supervisor do
  @moduledoc """
  ServerSupervisor supervises BittorrentClient Server
  """
  use Supervisor
  require Logger
  alias BittorrentClient.Server.Worker, as: Server
  # can take args
  def start_link do
    Logger.info fn -> "Starting Server Supervisor" end
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    children = [
      worker(Server, ["./", "GenericName"], id: {:server, "GenericName"})
    ]

    supervise(children, strategy: :one_for_one)
  end

end
