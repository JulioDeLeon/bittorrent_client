defmodule BittorrentClient.Torrent.GenServerImpl do
  @moduledoc """
  TorrentWorker handles on particular torrent magnet, manages the connections allowed and other settings.
  """
  @behaviour BittorrentClient.Torrent
  use GenServer
  require HTTPoison
  alias BittorrentClient.Torrent.Data, as: TorrentData
  alias BittorrentClient.Torrent.TrackerInfo, as: TrackerInfo
  alias BittorrentClient.Peer.Supervisor, as: PeerSupervisor
  alias BittorrentClient.Logger.Factory, as: LoggerFactory
  alias BittorrentClient.Logger.JDLogger, as: JDLogger

  @logger LoggerFactory.create_logger(__MODULE__)
  # @torrent_states [:initial, :connected, :started, :completed, :paused, :error]

  # -------------------------------------------------------------------------------
  # GenServer Callbacks
  # -------------------------------------------------------------------------------
  def start_link({id, filename}) do
    JDLogger.info(@logger, "Starting Torrent worker for #{filename}")

    torrent_metadata =
      filename
      |> File.read!()
      |> Bento.torrent!()

    JDLogger.debug(@logger, "Metadata: #{inspect(torrent_metadata)}")
    torrent_data = create_initial_data(id, filename, torrent_metadata)
    JDLogger.debug(@logger, "Data: #{inspect(torrent_data)}")

    GenServer.start_link(
      __MODULE__,
      {torrent_metadata, torrent_data},
      name: {:global, {:btc_torrentworker, id}}
    )
  end

  def init({torrent_metadata, torrent_data}) do
    {:ok, {torrent_metadata, torrent_data}}
  end

  def handle_call({:get_data}, _from, {metadata, data}) do
    ret = %{
      "metadata" => metadata,
      "data" => data
    }

    {:reply, {:ok, ret}, {metadata, data}}
  end

  def handle_call({:connect_to_tracker}, _from, {metadata, data}) do
    connect_to_tracker_helper({metadata, data})
  end

  def handle_call({:get_peers}, _from, {metadata, data}) do
    {:reply, {:ok, TorrentData.get_peers(data)}, {metadata, data}}
  end

  def handle_call({:start_single_peer, {ip, port}}, _from, {metadata, data}) do
    {s, peer_data} =
      PeerSupervisor.start_child(
        {metadata, Map.get(data, :id), Map.get(data, :info_hash),
         Map.get(data, :filename),
         data |> Map.get(:tracker_info) |> Map.get(:interval), ip, port}
      )

    case s do
      :error ->
        JDLogger.error(@logger, "Error: #{inspect(peer_data)}")

        {:reply,
         {:error,
          "Failed to start peer connection for #{inspect(ip)}:#{inspect(port)}: #{
            inspect(peer_data)
          }"}, {metadata, data}}

      :ok ->
        {:reply, {:ok, peer_data}, {metadata, data}}
    end
  end

  def handle_call({:start_torrent, id}, _from, {metadata, data}) do
    case data.status do
      :initial ->
        {:reply, {:error, {403, "#{id} has not connected to tracker"}},
         {metadata, data}}

      :error ->
        {:reply,
         {:error,
          {403, "#{id} has experienced an error somewhere. Will not connect."}},
         {metadata, data}}

      _ ->
        start_torrent_helper(id, {metadata, data})
    end
  end

  def handle_call({:get_next_piece_index, known_list}, _from, {metadata, data}) do
    case determine_next_piece(data.pieces, known_list) do
      {:ok, piece_index} ->
        new_piece_table = Map.merge(data.pieces, %{piece_index => :started})

        {:reply, {:ok, piece_index},
         {metadata, %TorrentData{data | pieces: new_piece_table}}}

      {:error, msg} ->
        {:reply, {:error, msg}, {metadata, data}}
    end
  end

  def handle_call(
        {:mark_piece_index_done, index, buffer},
        _from,
        {metadata, data}
      ) do
    piece_table = data.piece

    if Map.has_key?(piece_table, index) do
      new_piece_table = %{piece_table | index => {:done, buffer}}

      {:reply, {:ok, index},
       {metadata, %TorrentData{data | pieces: new_piece_table}}}
    else
      {:reply, {:error, "invalid index given: #{index}"}, {metadata, data}}
    end
  end

  def handle_call({:add_piece_index, peer_id, index}, _from, {metadata, data}) do
    {status, new_table, reason} = add_single_piece(peer_id, index, data.pieces)

    case status do
      :error ->
        {:reply, {:error, "Could not add #{index} to piece table: #{reason}"},
         {metadata, data}}

      :ok ->
        {:reply,
         {:ok, "Successfully added #{index} => #{peer_id} to piece table"},
         {metadata, %TorrentData{data | pieces: new_table}}}
    end
  end

  def handle_call({:add_multi_pieces, peer_id, lst}, _from, {metadata, data}) do
    {new_table, valid_indexes} =
      Enum.reduce(lst, {data.pieces, []}, fn elem, {acc, valid} ->
        {status, temp_table, _reason} = add_single_piece(peer_id, elem, acc)

        case status do
          :ok -> {temp_table, [elem | valid]}
          :error -> {temp_table, valid}
        end
      end)

    {:reply, {:ok, valid_indexes},
     {metadata, %TorrentData{data | pieces: new_table}}}
  end

  def handle_call({:delete_piece_index, index}, _from, {metadata, data}) do
    if index >= 0 and Map.has_key?(data.pieces, index) do
      {:reply, {:ok, Map.fetch!(data.pieces, index)},
       {metadata, %TorrentData{data | pieces: Map.delete(data.pieces, index)}}}
    else
      {:reply, {:error, "Invalid index"}, {metadata, data}}
    end
  end

  def handle_cast({:connect_to_tracker_async}, {metadata, data}) do
    {_, _, {new_metadata, new_data}} =
      connect_to_tracker_helper({metadata, data})

    {:noreply, {new_metadata, new_data}}
  end

  def handle_call({:get_completed_piece_list}, {metadata, data}) do
    completed_indexes =
      Enum.reduce(Map.keys(data.pieces), [], fn elem, acc ->
        {status, _} = Map.fetch!(data.pieces, elem)

        case status do
          :completed -> [elem | acc]
          _ -> acc
        end
      end)

    {:reply, completed_indexes, {metadata, data}}
  end

  # -------------------------------------------------------------------------------
  # Api Calls
  # -------------------------------------------------------------------------------
  def whereis(id) do
    :global.whereis_name({:btc_torrentworker, id})
  end

  def start_torrent(id) do
    JDLogger.info(@logger, "Starting torrent: #{id}")

    GenServer.call(
      :global.whereis_name({:btc_torrentworker, id}),
      {:start_torrent, id},
      :infinity
    )
  end

  def get_torrent_data(id) do
    JDLogger.info(@logger, "Getting torrent data for #{id}")
    GenServer.call(:global.whereis_name({:btc_torrentworker, id}), {:get_data})
  end

  def connect_to_tracker(id) do
    JDLogger.debug(@logger, "Torrent #{id} attempting to connect tracker")

    GenServer.call(
      :global.whereis_name({:btc_torrentworker, id}),
      {:connect_to_tracker},
      :infinity
    )
  end

  def connect_to_tracker_async(id) do
    JDLogger.debug(@logger, "Torrent #{id} attempting to connect tracker")

    GenServer.cast(
      :global.whereis_name({:btc_torrentworker, id}),
      {:connect_to_tracker_async}
    )
  end

  def get_peers(id) do
    JDLogger.debug(@logger, "Getting peer list of #{id}")
    GenServer.call(:global.whereis_name({:btc_torrentworker, id}), {:get_peers})
  end

  def start_single_peer(id, {ip, port}) do
    JDLogger.debug(
      @logger,
      "Starting a single peer for #{id} with #{inspect(ip)}:#{inspect(port)}"
    )

    GenServer.call(
      :global.whereis_name({:btc_torrentworker, id}),
      {:start_single_peer, {ip, port}}
    )
  end

  def get_next_piece_index(id, known_list) do
    JDLogger.debug(@logger, "#{id} is retrieving next_piece_index")

    GenServer.call(
      :global.whereis_name({:btc_torrentworker, id}),
      {:get_next_piece_index, known_list},
      :infinity
    )
  end

  def mark_piece_index_done(id, index, buffer) do
    JDLogger.debug(@logger, "#{id}'s peerworker has marked #{index} as done!")

    GenServer.call(
      :global.whereis_name({:btc_torrentworker, id}),
      {:mark_piece_index_done, index, buffer}
    )
  end

  def add_new_piece_index(id, peer_id, index) do
    JDLogger.debug(
      @logger,
      "#{id} is attempting to add new piece index: #{index}"
    )

    GenServer.call(
      :global.whereis_name({:btc_torrentworker, id}),
      {:add_piece_index, peer_id, index}
    )
  end

  def add_multi_pieces(id, peer_id, lst) do
    JDLogger.debug(@logger, "#{id} is attempting to add multliple pieces")

    GenServer.call(
      :global.whereis_name({:btc_torrentworker, id}),
      {:add_piece_index, peer_id, lst}
    )
  end

  def get_completed_piece_list(id) do
    JDLogger.debug(@logger, "#{id} is sending completed list")

    GenServer.call(
      :global.whereis_name({:btc_torrentworker, id}),
      {:get_completed_piece_list}
    )
  end

  # -------------------------------------------------------------------------------
  # Utility Functions
  # -------------------------------------------------------------------------------
  defp create_tracker_request(url, params) do
    url_params =
      for key <- Map.keys(params),
          do: "#{key}" <> "=" <> "#{Map.get(params, key)}"

    URI.encode(url <> "?" <> Enum.join(url_params, "&"))
  end

  defp parse_tracker_response(body) do
    {status, track_resp} = Bento.decode(body)
    JDLogger.debug(@logger, "tracker response decode -> #{inspect(track_resp)}")

    case status do
      :error ->
        {:error, %TrackerInfo{}}

      :ok ->
        {:ok,
         %TrackerInfo{
           interval: track_resp["interval"],
           peers: track_resp["peers"],
           peers6: track_resp["peers6"]
         }}
    end
  end

  defp connect_to_tracker_helper({metadata, data}) do
    # These either dont relate to tracker req or are not implemented yet
    JDLogger.debug(@logger, "connect_to_tracker_helper")

    unwanted_params = [
      :status,
      :id,
      :pid,
      :file,
      :trackerid,
      :tracker_info,
      :key,
      :ip,
      :pieces,
      :no_peer_id,
      :__struct__
    ]

    params =
      List.foldl(unwanted_params, data, fn elem, acc ->
        Map.delete(acc, elem)
      end)

    url = create_tracker_request(metadata.announce, params)
    # connect to tracker, respond based on what the http response is
    {status, resp} =
      HTTPoison.get(url, [], [{:timeout, 10_000}, {:recv_timeout, 10_000}])

    JDLogger.debug(@logger, "Response from tracker: #{inspect(resp)}")

    case status do
      :error ->
        JDLogger.error(@logger, "Failed to fetch #{url}")
        JDLogger.error(@logger, "Resp: #{inspect(resp)}")
        {:reply, {:error, "failed to fetch #{url}"}, {metadata, data}}

      _ ->
        # response returns a text/plain object
        IO.inspect(resp)
        {status, tracker_info} = parse_tracker_response(resp.body)

        case status do
          :error ->
            {:reply, {:error, "Failed to connect to tracker"},
             {metadata, Map.put(data, :status, :error)}}

          _ ->
            # update data
            updated_data =
              data
              |> Map.put(:tracker_info, tracker_info)
              |> Map.put(:status, :connected)

            {:reply, {:ok, {metadata, updated_data}}, {metadata, updated_data}}
        end
    end
  end

  defp create_initial_data(id, file, metadata) do
    {check, info} =
      metadata.info
      |> Map.from_struct()
      |> Map.delete(:md5sum)
      |> Map.delete(:private)
      |> Bento.encode()

    if check == :error do
      JDLogger.debug(@logger, "Failed to extract info from metadata")
      raise "Failed to extract info from metadata"
    else
      hash = :crypto.hash(:sha, info)

      %TorrentData{
        id: id,
        pid: self(),
        file: file,
        status: :initial,
        info_hash: hash,
        peer_id: Application.fetch_env!(:bittorrent_client, :peer_id),
        port: Application.fetch_env!(:bittorrent_client, :port),
        uploaded: 0,
        downloaded: 0,
        left: metadata.info.length,
        compact: Application.fetch_env!(:bittorrent_client, :compact),
        no_peer_id: Application.fetch_env!(:bittorrent_client, :no_peer_id),
        ip: Application.fetch_env!(:bittorrent_client, :ip),
        numwant: Application.fetch_env!(:bittorrent_client, :numwant),
        key: Application.fetch_env!(:bittorrent_client, :key),
        trackerid: "",
        tracker_info: %TrackerInfo{},
        pieces: %{},
        next_piece_index: 0,
        connected_peers: []
      }
    end
  end

  def parse_peers_binary(binary) do
    parse_peers_binary(binary, [])
  end

  def parse_peers_binary(<<a, b, c, d, fp, sp, rest::bytes>>, acc) do
    port = fp * 256 + sp
    parse_peers_binary(rest, [{{a, b, c, d}, port} | acc])
  end

  def parse_peers_binary(_, acc) do
    acc
  end

  def get_peer_list(id) do
    {_, tab} = get_peers(id)
    parse_peers_binary(tab)
  end

  defp determine_next_piece(piece_map, [fst | rst]) do
    if fst >= 0 and Map.has_key?(piece_map, fst) do
      case Map.fetch!(piece_map, fst) do
        :found -> {:ok, fst}
        _ -> determine_next_piece(piece_map, rst)
      end
    else
      determine_next_piece(piece_map, rst)
    end
  end

  defp determine_next_piece(_, []) do
    {:error, "no possible pieces available"}
  end

  defp add_single_piece(peer_id, index, piece_table) do
    cond do
      index < 0 ->
        {:error, piece_table, "Invalid index #{index}"}

      !Map.has_key?(piece_table, index) ->
        {:ok,
         %TorrentData{
           piece_table
           | pieces: Map.put(piece_table, index, {:found, [peer_id]})
         }, ""}

      true ->
        (fn ->
           {progress, lst} = Map.fetch!(piece_table, index)

           case progress do
             :found ->
               {:ok,
                %TorrentData{
                  piece_table
                  | pieces:
                      Map.put(piece_table, index, {:found, [peer_id | lst]})
                }, ""}

             _ ->
               {:error, piece_table,
                "#{index} is not available: #{inspect(progress)}"}
           end
         end).()
    end
  end

  defp start_torrent_helper(id, {metadata, data}) do
    peer_list = data |> TorrentData.get_peers() |> parse_peers_binary()

    case peer_list do
      [] ->
        {:reply, {:error, {403, "#{id} has no peers"}}, {metadata, data}}

      _ ->
        returned_pids =
          Enum.map(peer_list, fn {ip, port} ->
            PeerSupervisor.start_child(
              {metadata, Map.get(data, :id), Map.get(data, :info_hash),
               Map.get(data, :filename),
               data |> Map.get(:tracker_info) |> Map.get(:interval), ip, port}
            )
          end)

        {:reply, {:ok, "started torrent #{id}", returned_pids},
         {metadata, %TorrentData{data | status: :started}}}
    end
  end
end
