defmodule BittorrentClient.DatabaseWorker do
  use GenServer

  def start_link(database, worker_id) do
    IO.puts "Starting worker [#{worker_id}]"

    GenServer.start_link(
      __MODULE__,
      database,
      name: {:via, :gproc, {:n, :l, {:database_worker, worker_id}}}
    )
  end
  # handle_call
  # handle_cast
  def init(database) do
    {:ok, database}
  end
end
