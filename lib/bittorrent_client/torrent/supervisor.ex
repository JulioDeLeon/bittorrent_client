defmodule BittorrentClient.Torrent.Supervisor do
  @moduledoc """
  Torrent Supervisor will supervise torrent handler threads dynamically.
  """
  use Supervisor
  require Logger
  alias BittorrentClient.Torrent.Worker, as: TorrentWorker

  def start_link do
    Logger.info fn -> "Starting Torrent Supervisor" end
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    supervise([worker(TorrentWorker, [])],
      strategy: :simple_one_for_one)
  end

  def start_child({torrent_id, filename}) do
    Logger.info fn -> "Adding torrent id for: #{torrent_id} for #{__MODULE__}" end
    Supervisor.start_child(__MODULE__, [{torrent_id, filename}])
  end

  def terminate_child(torrent_pid) do
    Logger.info fn -> "Request to terminate #{torrent_pid}" end
    Supervisor.terminate_child(__MODULE__, torrent_pid)
  end
end
