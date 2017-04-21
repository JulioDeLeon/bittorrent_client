defmodule BittorrentClient.TorrentSupervisor do
  use Supervisor
  # start_link
  def start_link() do
    IO.puts "Starting torrent Supervisor"
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
	supervise([worker(BittorrentClient.TorrentWorker, [])], strategy: :simple_one_for_one)
  end

  def start_child(torrent_id) do
    Supervisor.start_child(__MODULE__, [torrent_id])
  end
end
