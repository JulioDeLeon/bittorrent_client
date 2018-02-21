defmodule BittorrentClient.Torrent.Supervisor do
  @moduledoc """
  Torrent Supervisor will supervise torrent handler threads dynamically.
  """
  use Supervisor
  require Logger
  @torrent_impl Application.get_env(:bittorrent_client, :torrent_impl)

  def start_link do
    Logger.info("Starting Torrent Supervisor")
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    supervise(
      [worker(@torrent_impl, [], restart: :temporary)],
      strategy: :simple_one_for_one
    )
  end

  def start_child({torrent_id, filename}) do
    Logger.info("Adding torrent id for: #{torrent_id} for #{__MODULE__}")

    ret = Supervisor.start_child(__MODULE__, [{torrent_id, filename}])
    ret
  end

  def terminate_child(torrent_id) do
    Logger.info("Request to terminate #{inspect(torrent_id)}")
    pid = @torrent_impl.whereis(torrent_id)

    case pid do
      :undefined ->
        {:error, "Torrent id: #{torrent_id} could not be found"}

      _ ->
        # tell torrent process to terminate it's related_children
        {:ok, Process.exit(pid, :kill)}
    end
  end
end
