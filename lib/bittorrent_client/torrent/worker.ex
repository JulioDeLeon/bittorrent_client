defmodule BittorrentClient.Torrent.Worker do
  @moduledoc """
  TorrentWorker handles on particular torrent magnet, manages the connections allowed and other settings.
  """
  use GenServer
  require HTTPoison
  require Logger
  alias BittorrentClient.Torrent.Data, as: TorrentData
  alias BittorrentClient.Torrent.TrackerInfo, as: TrackerInfo

  @on_load :load_nifs
  def load_nifs do
    :erlang.load_nif("./c_lib/peer_helper", 0)
  end

  def get_peer_connection_info(_byte_arr, _size) do
    raise "NIF get_peer_connection_info/2 not implemented"
  end

  def start_link({id, filename}) do
    Logger.info fn -> "Starting Torrent worker for #{filename}" end
    torrent_metadata = filename
    |> File.read!()
    |> Bento.torrent!()
    Logger.debug fn -> "Metadata: #{inspect torrent_metadata}" end
    torrent_data = create_initial_data(id, filename, torrent_metadata)
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

  def get_torrent_data(id) do
    Logger.info fn -> "Torrent metadata for #{id}" end
    GenServer.call(:global.whereis_name({:btc_torrentworker, id}),
      {:get_data})
  end

  def connect_to_tracker(id) do
    Logger.debug fn -> "Torrent #{id} attempting to connect tracker" end
      GenServer.call(:global.whereis_name({:btc_torrentworker, id}),
      	{:connect_to_tracker})
  end

  def handle_call({:get_data}, _from, {metadata, data}) do
    ret = %{
      "metadata" => metadata,
      "data" => data
    }
    {:reply, {:ok, ret}, {metadata, data}}
  end

  def handle_call({:connect_to_tracker}, _from, {metadata, data}) do
    # these have not been implemented yet
    unwanted_params = [:status,
                       :id,
                       :pid,
                       :file,
                       :trackerid,
                       :tracker_info,
                       :key,
                       :ip,
                       :no_peer_id,
                       :__struct__]
    params = List.foldl(unwanted_params, data,
      fn elem, acc -> Map.delete(acc, elem) end)
    url = create_tracker_request(metadata.announce, params)
    Logger.debug fn -> "url created: #{url}" end
    # connect to tracker, respond based on what the http response is
    {status, resp} = HTTPoison.get(url, [], [{:timeout, 1500}, {:recv_timeout, 1500}])
    Logger.debug fn -> "Response from tracker: #{inspect resp}" end
    case status do
      :error ->
        Logger.error fn -> "Failed to fetch #{url}" end
        Logger.error fn -> "Resp: #{inspect resp}" end
        {:reply, {:error, "Could not fetch #{url}"}, {metadata, data}}
      _ ->
        Logger.debug fn -> "Response from tracker: #{inspect resp}" end
        # response returns a text/plain object
        {status, tracker_info} = parse_tracker_response(resp.body)
        case status do
          :error -> {:reply, {:error, "Failed to connect to tracker"}, {metadata, Map.put(data, :status, "failed")}}
          _ ->
          # update data
            updated_data =  data
            |> Map.put(:tracker_info, tracker_info)
            |> Map.put(:status, "started")
            {:reply, {:ok, {metadata, updated_data}}, {metadata, updated_data}}
        end
    end
  end

  # UTILITY
  defp create_tracker_request(url, params) do
   	url_params = for key <- Map.keys(params), do: "#{key}" <> "=" <> "#{Map.get(params, key)}"
    URI.encode(url <> "?" <> Enum.join(url_params, "&"))
  end

  defp parse_tracker_response(body) do
    {status, track_resp} = Bento.decode(body)
    Logger.debug fn -> "tracker response decode -> #{inspect track_resp}" end
    case status do
      :error -> {:error, %TrackerInfo{}}
      _ ->
        {:ok, %TrackerInfo{
            interval: track_resp["interval"],
            peers: track_resp["peers"],
            peers6: track_resp["peers6"]
         }}
    end
  end

  defp create_initial_data(id, file, metadata) do
    {check, info} = metadata.info
    |> Map.from_struct()
    |> Map.delete(:md5sum)
    |> Map.delete(:private)
    |> Bento.encode()
    if check == :error do
      Logger.debug fn -> "Failed to extract info from metadata" end
      %TorrentData{}
    else
      hash = :crypto.hash(:sha, info)
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
        trackerid: Application.fetch_env!(:bittorrent_client, :trackerid),
        tracker_info: %TrackerInfo{}
      }
    end
  end

  """
  https://github.com/lita/bittorrent/blob/master/peers.py
  python example
    for chunk in self.chunkToSixBytes(response):
      ip = []
      port = None
      for i in range(0, 4):
        ip.append(str(ord(chunk[i])))

      port = ord(chunk[4])*256+ord(chunk[5])
      mySocket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
      mySocket.setblocking(0)
      ip = '.'.join(ip)
      peer = Peer(ip, port, mySocket, self.infoHash, self.peer_id)
      self.peers.append(peer)
  """
  defp parse_peer_byte_array(peer_byte_array) do
    peers = peer_byte_array
    |> :binary.bin_to_list()
    |> Enum.chunk(6)
    |> Enum.map(fn single_ip_chunk ->
        # if these strings do not print to temrinal correctly, check unicode support
        ip = Enum.take(single_ip_chunk, 4) |> Enum.join(".")
        port = Enum.drop(single_ip_chunk, 4) |> fn [f, s | r] -> f*256+s end.()
        {ip, port}
        end)
  end
end
