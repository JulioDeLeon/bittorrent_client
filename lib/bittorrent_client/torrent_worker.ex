defmodule BittorrentClient.TorrentWorker do
  use GenServer
  @moduledoc """
  TorrentWorker handles on particular torrent magnet, manages the connections allowed and other settings. 
  """

  def start_link(id, filename) do
    IO.puts "Starting torrent worker for #{filename}"
	torrentMetadata = filename
    |> File.read!()
    |> Bento.torrent!()

    GenServer.start_link(
      __MODULE__,
      {torrentMetadata},
      name: {:global, {:btc_torrentworker, id}}
    )
  end

  def init(torrentMetadata) do
    {:ok, torrentMetadata}
  end

  def whereis(id) do
    :global.whereis_name({:btc_torrentworker, id})
  end

  def getTorrentMetaData(id) do
    IO.puts "Torrent metadata for #{id}"
    GenServer.call(:global.whereis_name({:btc_torrentworker, id}),
      {:get_metadata})
  end

  def handle_call({:get_metadata}, _from, {metadata}) do
    {:reply, {:ok, metadata}, {metadata}}
  end

  defp createTrackerRequest(url, params) do
   	urlParams = for key <- Map.keys(params), do: "#{key}" <> "=" <> "#{Map.get(params, key)}"
    URI.encode(url <> "?" <> Enum.join(urlParams, "&"))
  end

  defp connectToTracker(id) do
    metadata = getTorrentMetaData(id)
    url = createTrackerRequest(metadata.announce, %{"peer_id" => "-ET0001-"})
  end
end
