defmodule BittorrentClient.TorrentWorker do
  use GenServer
  @moduledoc """
  TorrentWorker handles on particular torrent magnet, manages the connections allowed and other settings. 
  """

  def start_link(filename) do
    IO.puts "Starting torrent worker for #{filename}"
	torrentMetadata = filename
    |> File.read!()
    |> Bento.torrent!()

    GenServer.start_link(
      __MODULE__,
      {torrentMetadata},
      name: {:global, {:btc_torrentworker, filename}}
    )
  end

  def init(torrentMetadata) do
    {:ok, torrentMetadata}
  end

  def whereis(name) do
    :global.whereis_name({:btc_torrentworker, name})
  end

  def getTorrentMetaData(name) do
    IO.puts "Torrent metadata for #{name}"
    GenServer.call(:global.whereis_name({:btc_torrentworker, name}),
      {:get_metadata})
  end

  def handle_call({:get_metadata}, _from, {metadata}) do
    {:reply, {:ok, metadata}, {metadata}}
  end

  defp createTrackerRequest(url, params) do
   	urlParams = for key <- Map.keys(params), do: "#{key}" <> "=" <> "#{Map.get(params, key)}"
    URI.encode(url <> "?" <> Enum.join(urlParams, "&"))
  end

  defp connectToTracker(name) do
    metadata = getTorrentMetaData(name)
    url = createTrackerRequest(metadata.announce, {"peer_id" => "-ET0001-",
                                                   "" => ""})
  end
end
