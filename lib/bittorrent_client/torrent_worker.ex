defmodule BittorrentClient.TorrentWorker do
  use GenServer
  @moduledoc """
  TorrentWorker handles on particular torrent magnet, manages the connections allowed and other settings. 
  """
  require Logger

  def start_link({id, filename}) do
    Logger.info "Starting Torrent worker for #{filename}"
    torrent_metadata = filename
    |> File.read!()
    |> Bento.torrent!()
    GenServer.start_link(
      __MODULE__,
      {torrent_metadata},
      name: {:global, {:btc_torrentworker, id}}
    )
  end

  def init(torrent_metadata) do
    {:ok, torrent_metadata}
  end

  def terminate(reason, _state) do
    Logger.info "terminating #{inspect self}: #{inspect reason}"
  end

  def whereis(id) do
    :global.whereis_name({:btc_torrentworker, id})
  end

  def getTorrentMetaData(id) do
    Logger.info "Torrent metadata for #{id}"
    GenServer.call(:global.whereis_name({:btc_torrentworker, id}),
      {:get_metadata})
  end

  def handle_call({:get_metadata}, _from, {metadata}) do
    {:reply, {:ok, metadata}, {metadata}}
  end

  defp createTrackerRequest(url, params) do
   	url_params = for key <- Map.keys(params), do: "#{key}" <> "=" <> "#{Map.get(params, key)}"
    URI.encode(url <> "?" <> Enum.join(url_params, "&"))
  end

  defp connectToTracker(id) do
    metadata = getTorrentMetaData(idimport Supervisor.Spec)
    url = createTrackerRequest(metadata.announce, %{"peer_id" => "-ET0001-"})
  end
end
