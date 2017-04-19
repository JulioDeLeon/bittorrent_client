defmodule BittorrentClient.TorrentSupervisor do
  use Supervisor
  # start_link
  def start_link() do
    IO.puts "Starting torrent Supervisor"
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  # init -> supervise
  def init(:ok) do

  end
end
