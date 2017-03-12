defmodule BittorrentClient.ServerSupervisor do
  use Supervisor

  # can take args
  def start_link do
    IO.puts "Starting Server Supervisor"
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    children = [
      worker(BittorrentClient.Server, ["./", "GenericName"], id: {:server,"GenericName"})
    ]

    supervise(children, strategy: :one_for_one)
  end
end
