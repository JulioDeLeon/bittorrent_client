defmodule BittorrentClient.TorrentSupervisor do
  @moduledoc """
  Torrent Supervisor will supervise torrent handler threads dynamically.
  """
  use Supervisor
  require Logger

  # start_link
  def start_link do
    Logger.info "Starting Torrent Supervisor"
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    supervise([worker(BittorrentClient.TorrentWorker, [])],
      strategy: :simple_one_for_one)
  end

  def start_child({torrent_id, filename}) do
    Supervisor.start_child(__MODULE__, [{torrent_id, filename}])
  end
end
