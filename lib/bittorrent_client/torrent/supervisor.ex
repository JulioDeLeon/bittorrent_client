defmodule BittorrentClient.Torrent.Supervisor do
  @moduledoc """
  Torrent Supervisor will supervise torrent handler threads dynamically.
  """
  use DynamicSupervisor
  require Logger
  @torrent_impl Application.compile_env(:bittorrent_client, :torrent_impl)

  def start_link do
    Logger.info("Starting Torrent Supervisor")
    DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child({torrent_id, filename}) do
    Logger.info("Adding torrent id for: #{torrent_id} for #{__MODULE__}")

    child_spec = %{
      id: @torrent_impl,
      start: {@torrent_impl, :start_link, [{torrent_id, filename}]},
      restart: :temporary
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
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
