defmodule BittorrentClient.TorrentSupervisor do
  use Supervisor
  # start_link
  def start_link(server, filename) do
    IO.puts "Starting torrent Supervisor for #{filename}"
    Supervisor.start_link(__MODULE__,filename)
  end

  # init -> supervise
  def init(server, filename) do
    children = [
      worker(BittorrentClient.TorrentWorker, [server, filename], id: {:btc_torrentworker, filename})
    ]

    supervise(children, strategy: :one_for_one)
  end
end
