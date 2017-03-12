defmodule BittorrentClient.DBWorkerSupervisor do
  use Supervisor

  def start_link(database, poolsize) do
    IO.puts "Starting DataBaseSupervisor"
    Supervisor.start_link(__MODULE__, {database, poolsize})
  end

  def init({database, poolsize}) do
    children = for worker_id <- 1..poolsize do
      worker(
        BittorrentClient.DatabaseWorker, [database, worker_id],
        id: {:database_worker, worker_id}
      )
    end

    supervise(children, strategy: :one_for_one)
  end
end
