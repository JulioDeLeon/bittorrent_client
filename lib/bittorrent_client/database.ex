defmodule BittorrentClient.Database do
  use GenServer
  @poolsize 10

  def start_link(database) do
    IO.puts "Starting Database"
    BittorrentClient.DBWorkerSupervisor.start_link(database, @poolsize)
  end


end
