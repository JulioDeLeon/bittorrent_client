defmodule BittorrentClient.ServerSupervisor do
  @moduledoc """
  ServerSupervisor supervises BittorrentClient Server
  """
  use Supervisor
  require Logger

  # can take args
  def start_link do
    Logger.info "Starting Server Supervisor"
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    children = [
      worker(BittorrentClient.Server, ["./", "GenericName"], id: {:server, "GenericName"})
    ]

    supervise(children, strategy: :one_for_one)
  end

end
