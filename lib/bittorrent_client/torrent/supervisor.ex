defmodule BittorrentClient.Torrent.Supervisor do
  @moduledoc """
  Torrent Supervisor will supervise torrent handler threads dynamically.
  """
  use Supervisor
  require Logger
  alias BittorrentClient.Torrent.Worker, as: TorrentWorker

  # start_link
  def start_link do
    Logger.info "Starting Torrent Supervisor"
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    supervise([worker(TorrentWorker, [])],
      strategy: :simple_one_for_one)
  end

  def start_child({torrent_id, filename}) do
    Logger.debug "Adding torrent id for: #{torrent_id} for #{__MODULE__}"
    Supervisor.start_child(__MODULE__, [{torrent_id, filename}])
  end

  def terminate_child(torrent_pid) do
    Supervisor.terminate_child(__MODULE__, torrent_pid)
  end
end
