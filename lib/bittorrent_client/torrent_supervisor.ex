defmodule BittorrentClient.TorrentSupervisor do
  use Supervisor
  # start_link
  def start_link(filename) do
    IO.puts "Starting torrent Supervisor for #{filename}"
    Supervisor.start_link(__MODULE__,filename)
  end

  # init -> supervise
  def init(filename) do
    
  end
end
