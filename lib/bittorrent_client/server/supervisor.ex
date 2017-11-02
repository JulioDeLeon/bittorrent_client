defmodule BittorrentClient.Server.Supervisor do
  @moduledoc """
  ServerSupervisor supervises BittorrentClient Server
  """
  use Supervisor
  require Logger
  alias BittorrentClient.Server.Worker, as: Server

  def start_link([name]) do
    Logger.info fn -> "Starting Server Supervisor" end
    Supervisor.start_link(__MODULE__, [name])
  end

  def init([name]) do
    children = [
      worker(Server, ["./", name], id: {:server, name})
    ]

    supervise(children, strategy: :one_for_one)
  end
end
