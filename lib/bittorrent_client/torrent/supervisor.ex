defmodule BittorrentClient.Torrent.Supervisor do
  @moduledoc """
  Torrent Supervisor will supervise torrent handler threads dynamically.
  """
  use Supervisor
  # require Logger
  alias BittorrentClient.Logger.Factory, as: LoggerFactory
  alias BittorrentClient.Logger.JDLogger, as: JDLogger

  @torrent_impl Application.get_env(:bittorrent_client, :torrent_impl)
  @logger LoggerFactory.create_logger(__MODULE__)

  def start_link do
    # Logger.info fn -> "Starting Torrent Supervisor" end
    JDLogger.info(@logger, "Starting Torrent Supervisor")
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    supervise(
      [worker(@torrent_impl, [], restart: :temporary)],
      strategy: :simple_one_for_one,
    )
  end

  def start_child({torrent_id, filename}) do
    # Logger.info fn -> "Adding torrent id for: #{torrent_id} for #{__MODULE__}" end
    JDLogger.info(
      @logger,
      "Adding torrent id for: #{torrent_id} for #{__MODULE__}"
    )

    ret = Supervisor.start_child(__MODULE__, [{torrent_id, filename}])
    ret
  end

  def terminate_child(torrent_pid) do
    # Logger.info fn -> "Request to terminate #{torrent_pid}" end
    JDLogger.info(@logger, "Request to terminate #{torrent_pid}")
    pid = @torrent_impl.whereis(torrent_pid)
    Process.exit(pid, :normal)
  end
end
