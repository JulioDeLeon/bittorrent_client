defmodule BittorrentClient.Torrent.Worker do
  @moduledoc """
  TorrentWorker handles on particular torrent magnet, manages the connections allowed and other settings.
  """
  use GenServer
  require Logger
  alias BittorrentClient.Torrent.Data, as: TorrentData

  def start_link({id, filename}) do
    Logger.info fn -> "Starting Torrent worker for #{filename}" end
    torrent_metadata = filename
    |> File.read!()
    |> Bento.torrent!()
    Logger.debug fn -> "Metadata: #{inspect torrent_metadata}" end
    torrent_data = createInitialData(id, filename, torrent_metadata)
    Logger.debug fn -> "Data: #{inspect torrent_data}" end
    GenServer.start_link(
      __MODULE__,
      {torrent_metadata, torrent_data},
      name: {:global, {:btc_torrentworker, id}}
    )
  end

  def init(torrent_metadata, torrent_data) do
    {:ok, {torrent_metadata, torrent_data}}
  end

  def terminate(id, reason, _state) do
    pid = whereis(id)
    Logger.info fn -> "terminating #{inspect pid}: #{inspect reason}" end
    # terminate the given pid
  end

  def whereis(id) do
    :global.whereis_name({:btc_torrentworker, id})
  end

  def getTorrentData(id) do
    Logger.info fn -> "Torrent metadata for #{id}" end
    GenServer.call(:global.whereis_name({:btc_torrentworker, id}),
      {:get_data})
  end

  def connectToTracker(id) do
    Logger.debug fn -> "Torrent #{id} attempting to connect tracker" end
      GenServer.call(:global.whereis_name({:btc_torrentworker, id}),
      	{:connect_to_tracker})
  end

  def handle_call({:get_data}, _from, {metadata, data}) do
    {:reply, {:ok, {metadata, data}}, {metadata, data}}
  end

  def handle_call({:connect_to_tracker}, _from, {metadata, data}) do
	# this will change overtime
    unwanted_params = [:__struct__, :status, :id, :pid, :file, :trackerid, :key, :ip, :no_peer_id]
    params = List.foldl(unwanted_params, data, fn elem, acc -> Map.delete(acc, elem) end)
    url = createTrackerRequest(metadata.announce, params)
    Logger.debug fn -> "url created: #{url}" end
    # connect to tracker, respond based on what the http response is
    # change state of data, example would be changing event from started to completed/stopped
    # the response may return a json/object which can be parsed in a map
    # foldl the returned map to change state of data
    {:reply, :ok, {metadata, data}}
  end

  # UTILITY
  defp createTrackerRequest(url, params) do
   	url_params = for key <- Map.keys(params), do: "#{key}" <> "=" <> "#{Map.get(params, key)}" 
    URI.encode(url <> "?" <> Enum.join(url_params, "&"))
  end

  defp createInitialData(id, file, metadata) do
    {check, info} = metadata.info
    |> Map.from_struct
    |> Map.delete(:md5sum)
    |> Map.delete(:private)
    |> Bento.encode
    if check == :error do
      Logger.debug fn -> "Failed to extract info from metadata" end
      %TorrentData{}
    else
      hash = :crypto.hash(:sha, info)
      Logger.debug fn -> "Hash created: #{hash}" end
      %TorrentData{
        id: id,
        pid: self(),
        file: file,
        event: "started",
        peer_id: Application.fetch_env!(:bittorrent_client, :peer_id),
        compact: Application.fetch_env!(:bittorrent_client, :compact),
        port: Application.fetch_env!(:bittorrent_client, :port),
        uploaded: 0,
        downloaded: 0,
        left: metadata.info.length,
        info_hash: hash,
        no_peer_id: Application.fetch_env!(:bittorrent_client, :no_peer_id),
        ip: Application.fetch_env!(:bittorrent_client, :ip),
        numwant: Application.fetch_env!(:bittorrent_client, :numwant),
        key: Application.fetch_env!(:bittorrent_client, :key),
        trackerid: Application.fetch_env!(:bittorrent_client, :trackerid)
      }
    end
  end

  defp parseMetadata(meta_data) do
    %TorrentData{}
  end
end
