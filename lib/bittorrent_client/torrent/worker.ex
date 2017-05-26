defmodule BittorrentClient.Torrent.Worker do
  @moduledoc """
  TorrentWorker handles on particular torrent magnet, manages the connections allowed and other settings.
  """
  use GenServer
  require Logger

  def start_link({id, filename}) do
    Logger.info fn -> "Starting Torrent worker for #{filename}" end
    torrent_metadata = filename
    |> File.read!()
    |> Bento.torrent!()
    Logger.debug fn -> "Metadata: #{inspect torrent_metadata}" end
    GenServer.start_link(
      __MODULE__,
      {torrent_metadata},
      name: {:global, {:btc_torrentworker, id}}
    )
  end

  def init(torrent_metadata) do
    {:ok, torrent_metadata}
  end

  def terminate(id, reason, _state) do
    pid = whereis(id)
    Logger.info fn -> "terminating #{inspect pid}: #{inspect reason}" end
    # terminate the given pid
  end

  def whereis(id) do
    :global.whereis_name({:btc_torrentworker, id})
  end

  def getTorrentMetaData(id) do
    Logger.info fn -> "Torrent metadata for #{id}" end
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
    metadata = getTorrentMetaData(id)
    url = createTrackerRequest(metadata.announce, %{"peer_id" => "-ET0001-"})
  end

  defp createInitialTrackerParams(metadata) do
    %{
      "peer_id" => Application.fetch_env!(:BittorrentClient, :peer_id),
      "compact" => Application.fetch_env!(:BittorrentClient, :compact),
      "port" => Application.fetch_env!(:BittorrentClient, :port),
      "uploaded" => 0,
      "downloaded" => 0,
      # TODO: get left
      "left" => metadata["info"]["length"],
      # TODO: get info_hash
      "info_hash" => "#{:crypto.hash(:sha, metadata["info"])}"
    }
  end
end
