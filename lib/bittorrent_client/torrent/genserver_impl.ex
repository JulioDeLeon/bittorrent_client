defmodule BittorrentClient.Torrent.GenServerImpl do
  @moduledoc """
  TorrentWorker handles on particular torrent magnet, manages the connections allowed and other settings.
  """
  @behaviour BittorrentClient.Torrent
  use GenServer
  require HTTPoison
  require Logger
  alias Bento.Encoder, as: BenEncoder
  alias BittorrentClient.Peer.Supervisor, as: PeerSupervisor
  alias BittorrentClient.Torrent.Data, as: TorrentData
  alias BittorrentClient.Torrent.DownloadStrategies, as: DownloadStrategies
  alias BittorrentClient.Torrent.FileAssembler, as: FileAssembler
  alias BittorrentClient.Torrent.TrackerInfo, as: TrackerInfo
  @http_handle_impl Application.get_env(:bittorrent_client, :http_handle_impl)
  @torrent_cache_impl Application.get_env(
                        :bittorrent_client,
                        :torrent_cache_impl
                      )
  @torrent_cache_name Application.get_env(
                        :bittorrent_client,
                        :torrent_cache_name
                      )
  @piece_hash_length 20
  @destination_dir Application.get_env(:bittorrent_client, :file_destination)
  @peer_check_interval Application.get_env(
                         :bittorrent_client,
                         :peer_check_interval
                       )

  # @torrent_states [:initial, :connected, :started, :completed, :paused, :error]

  # -------------------------------------------------------------------------------
  # GenServer Callbacks
  # -------------------------------------------------------------------------------
  def start_link({id, filename}) do
    Logger.info("Starting Torrent worker for #{filename}")
    Logger.debug(fn -> "Using http_handle_impl: #{@http_handle_impl}" end)

    torrent_metadata =
      filename
      |> File.read!()
      |> Bento.torrent!()

    {:ok, torrent_data} = create_initial_data(id, filename, torrent_metadata)

    GenServer.start_link(
      __MODULE__,
      {torrent_metadata, torrent_data},
      name: {:global, {:btc_torrentworker, id}}
    )
  end

  def init({torrent_metadata, torrent_data}) do
    Logger.debug(fn -> "Metadata: #{inspect(torrent_metadata)}" end)
    Logger.debug(fn -> "Data: #{inspect(torrent_data)}" end)
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
    {status, peer_data} =
      PeerSupervisor.start_child(
        {metadata, Map.get(data, :id), Map.get(data, :info_hash),
         Map.get(data, :filename),
         data |> Map.get(:tracker_info) |> Map.get(:interval), ip, port}
      )

    case status do
      :error ->
        Logger.error("Error: #{inspect(peer_data)}")

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

  def handle_call({:stop_torrent}, _from, {metadata, data}) do
    case data.status do
      # check if start is started
      # if started, kill all pids currently working
      # stop timer associated with check peer list
      :started ->
        :erlang.cancel_timer(data.peer_timer)
        peer_list = Map.keys(data.connected_peers)
        handle_stopping_all_peers(peer_list)

        {:reply, {:ok, peer_list}, { metadata,
          %TorrentData{
            data |
            peer_timer: nil,
            status: :initial,
            connected_peers: []
          }
        }}

      some_state ->
        raise "Trying to stop torrent process in #{inspect some_state}"
    end
  end

  def handle_call({:get_next_piece_index, known_list}, _from, {metadata, data}) do
    case DownloadStrategies.determine_next_piece(
           :rarest_piece,
           data.pieces,
           known_list
         ) do
      {:ok, piece_index} ->
        {_, new_piece_table} =
          Map.get_and_update(data.pieces, piece_index, fn {status, ref_count,
                                                           buff} ->
            {{status, ref_count, buff}, {:started, ref_count, buff}}
          end)

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
    piece_table = data.pieces

    is_valid? = fn ->
      metadata.info.pieces
      |> pack_piece_list()
      |> validate_piece(index, buffer)
    end

    handle_valid_piece = fn piece_id ->
      Logger.debug(fn ->
        "#{data.id} : marking #{index} as complete. Writing to disk cache"
      end)

      new_piece_table = %{piece_table | index => {:complete, 0, <<>>}}

      {status, val} =
        :mnesia.transaction(fn ->
          :mnesia.write(
            {@torrent_cache_name, piece_id, data.file, index, :complete, buffer}
          )
        end)

      if status == :aborted do
        raise "Write was aborted! #{inspect(val)}"
      end

      num_completed =
        new_piece_table
        |> Map.values()
        |> Enum.filter(fn {status, _index, _buff} -> status == :complete end)
        |> length()

      ret_data = %TorrentData{data | pieces: new_piece_table}

      prog = (num_completed / data.num_pieces) * 10
      Logger.info("#{data.id} : #{prog}% complete")

      if num_completed == data.num_pieces do
        handle_complete_data({metadata, ret_data})
      end

      {:reply, {:ok, index}, {metadata, ret_data}}
    end

    {validation, id} = is_valid?.()

    cond do
      Map.has_key?(piece_table, index) == false ->
        {:reply, {:error, "invalid index given: #{index}"}, {metadata, data}}

      validation == false ->
        {:reply,
         {:error, "hash did not match expected hash for index given: #{index}"},
         {metadata, data}}

      true ->
        handle_valid_piece.(id)
    end
  end

  def handle_call({:add_piece_index, peer_id, index}, _from, {metadata, data}) do
    case add_single_piece(peer_id, index, data.pieces) do
      {:error, reason} ->
        {:reply, {:error, reason}, {metadata, data}}

      {:ok, new_piece_table} ->
        {:reply,
         {:ok,
          "Successfully updated #{index} to piece table : added #{peer_id} to table"},
         {metadata, %TorrentData{data | pieces: new_piece_table}}}
    end
  end

  def handle_call({:add_multi_pieces, peer_id, lst}, _from, {metadata, data}) do
    handle_single_piece = fn elem, {piece_table, valid_indexes} ->
      case add_single_piece(peer_id, elem, piece_table) do
        {:ok, n_table} ->
          {n_table, [elem | valid_indexes]}

        {:error, _reason} ->
          {piece_table, valid_indexes}
      end
    end

    {new_table, valid_indexes} =
      Enum.reduce(lst, {data.pieces, []}, handle_single_piece)

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

  def handle_call({:get_completed_piece_list}, _from, {metadata, data}) do
    completed_indexes =
      Enum.reduce(Map.keys(data.pieces), [], fn elem, acc ->
        {status, _, _} = Map.fetch!(data.pieces, elem)

        case status do
          :completed -> [elem | acc]
          _ -> acc
        end
      end)

    {:reply, {:ok, completed_indexes}, {metadata, data}}
  end

  def handle_call({:set_number_peers, num_wanted}, _from, {metadata, data})
      when num_wanted < 0 do
    {:reply, {:error, "invalid number of wanted peers was given"},
     {metadata, data}}
  end

  def handle_call({:set_number_peers, num_wanted}, _from, {metadata, data}) do
    {:reply, :ok, {metadata, %TorrentData{data | numwant: num_wanted}}}
  end

  def handle_call(
        {:notify_peer_connected, peer_id, peer_ip, peer_port},
        _from,
        {metadata, data}
      ) do
    new_connected_peers =
      data.connected_peers
      |> Map.put(peer_id, {peer_ip, peer_port})

    new_data =
      data
      |> Map.put(:connected_peers, new_connected_peers)

    {:reply, {:ok, true}, {metadata, new_data}}
  end

  def handle_call(
        {:notify_peer_disconnected, peer_id, peer_ip, peer_port, known_indexes},
        _from,
        {metadata, data}
      ) do
    if Map.has_key?(data.connected_peers, peer_id) do
      new_connected =
        data.connected_peers
        |> Map.delete(peer_id)

      new_pieces =
        known_indexes
        |> Enum.reduce(data.pieces, fn elem, acc ->
          case remove_ref_from_single_piece(acc, elem) do
            {:error, _} ->
              acc

            {:ok, new_table} ->
              new_table
          end
        end)

      new_data =
        data
        |> Map.put(:connected_peers, new_connected)
        |> Map.put(:pieces, new_pieces)
        |> TorrentData.remove_bad_ip_from_peers(peer_ip, peer_port)

      {:reply, {:ok, known_indexes}, {metadata, new_data}}
    else
      {:reply, {:error, "Given peer id #{peer_id} does not exist"},
       {metadata, data}}
    end
  end

  def handle_cast({:connect_to_tracker_async}, {metadata, data}) do
    {_, _, {new_metadata, new_data}} =
      connect_to_tracker_helper({metadata, data})

    {:noreply, {new_metadata, new_data}}
  end

  def handle_info({:timeout, timer, :peer_check}, {metadata, data}) do
    :erlang.cancel_timer(timer)

    num_connect =
      data.connected_peers
      |> Map.keys()
      |> length()

    num_need = data.numallowed - num_connect

    if num_need > 0 do
      Logger.debug("#{data.id} needs #{num_need} peers")
      # connect to tracker for new peers
      # send peer connection requests
      # reset timer
      # return
      case connect_to_tracker_helper({metadata, data}) do
        {:reply, {:ok, _ret_state}, {n_mdata, n_data}} ->
          peer_list =
            data.tracker_info.peers
            |> Enum.shuffle()
            |> Enum.take(num_need)

          pids = connect_to_peers(peer_list, {n_mdata, n_data})
          Logger.debug(fn -> "returned pids: #{inspect(pids)}" end)

          timer = :erlang.start_timer(@peer_check_interval, self(), :peer_check)

          {:noreply,
           {n_mdata, %TorrentData{n_data | status: :started, peer_timer: timer}}}

        {:reply, {:error, msg}, {n_mdata, n_data}} ->
          Logger.error(msg)

          timer = :erlang.start_timer(@peer_check_interval, self(), :peer_check)
          {:noreply, {n_mdata, %TorrentData{n_data | peer_timer: timer}}}
      end
    else

      timer = :erlang.start_timer(@peer_check_interval, self(), :peer_check)
      {:noreply, {metadata, %TorrentData{data | peer_timer: timer}}}
    end
  end

  # -------------------------------------------------------------------------------
  # Api Calls
  # -------------------------------------------------------------------------------
  def whereis(id) do
    :global.whereis_name({:btc_torrentworker, id})
  end

  def start_torrent(id) do
    Logger.info("Starting torrent: #{id}")

    GenServer.call(
      :global.whereis_name({:btc_torrentworker, id}),
      {:start_torrent, id},
      :infinity
    )
  end

  def stop_torrent(id) do
    Logger.info("Stopping torrent: #{id}")

    GenServer.call(
      :global.whereis_name({:btc_torrentworker, id}),
      {:stop_torrent},
      :infinity
    )
  end

  def get_torrent_data(id) do
    Logger.info("Getting torrent data for #{id}")
    GenServer.call(:global.whereis_name({:btc_torrentworker, id}), {:get_data})
  end

  def connect_to_tracker(id) do
    Logger.debug(fn -> "Torrent #{id} attempting to connect tracker" end)

    GenServer.call(
      :global.whereis_name({:btc_torrentworker, id}),
      {:connect_to_tracker},
      :infinity
    )
  end

  def connect_to_tracker_async(id) do
    Logger.debug(fn -> "Torrent #{id} attempting to connect tracker" end)

    GenServer.cast(
      :global.whereis_name({:btc_torrentworker, id}),
      {:connect_to_tracker_async}
    )
  end

  def get_peers(id) do
    Logger.debug(fn -> "Getting peer list of #{id}" end)
    GenServer.call(:global.whereis_name({:btc_torrentworker, id}), {:get_peers})
  end

  def start_single_peer(id, {ip, port}) do
    Logger.debug(fn ->
      "Starting a single peer for #{id} with #{inspect(ip)}:#{inspect(port)}"
    end)

    GenServer.call(
      :global.whereis_name({:btc_torrentworker, id}),
      {:start_single_peer, {ip, port}}
    )
  end

  def get_next_piece_index(id, known_list) do
    Logger.debug(fn -> "#{id} is retrieving next_piece_index" end)

    GenServer.call(
      :global.whereis_name({:btc_torrentworker, id}),
      {:get_next_piece_index, known_list},
      :infinity
    )
  end

  def mark_piece_index_done(id, index, buffer) do
    Logger.debug(fn -> "#{id}'s peerworker has marked #{index} as done!" end)

    GenServer.call(
      :global.whereis_name({:btc_torrentworker, id}),
      {:mark_piece_index_done, index, buffer}
    )
  end

  def add_new_piece_index(id, peer_id, index) do
    Logger.debug(fn ->
      "#{id} is attempting to add new piece index: #{index}"
    end)

    GenServer.call(
      :global.whereis_name({:btc_torrentworker, id}),
      {:add_piece_index, peer_id, index}
    )
  end

  def add_multi_pieces(id, peer_id, lst) do
    Logger.debug(fn -> "#{id} is attempting to add multiple pieces" end)

    GenServer.call(
      :global.whereis_name({:btc_torrentworker, id}),
      {:add_multi_pieces, peer_id, lst}
    )
  end

  def get_completed_piece_list(id) do
    Logger.debug(fn -> "#{id} is sending completed list" end)

    GenServer.call(
      :global.whereis_name({:btc_torrentworker, id}),
      {:get_completed_piece_list}
    )
  end

  def set_number_peers(id, num_wanted) do
    Logger.debug(fn -> "#{id} is setting number of peers" end)

    GenServer.call(
      :global.whereis_name({:btc_torrentworker, id}),
      {:set_number_peers, num_wanted}
    )
  end

  def notify_peer_is_connected(id, peer_id, peer_ip, peer_port) do
    Logger.debug(fn ->
      "#{id} is being notified that #{peer_id} is connected to its peer"
    end)

    GenServer.call(
      :global.whereis_name({:btc_torrentworker, id}),
      {:notify_peer_connected, peer_id, peer_ip, peer_port}
    )
  end

  def notify_peer_is_disconnected(
        id,
        peer_id,
        peer_ip,
        peer_port,
        known_indexes
      ) do
    Logger.debug(fn ->
      "#{id} is being notified that #{peer_id} is not connected to its peer"
    end)

    Logger.debug(fn ->
      "#{id} will reduce references for [#{inspect(known_indexes)}]"
    end)

    GenServer.call(
      :global.whereis_name({:btc_torrentworker, id}),
      {:notify_peer_disconnected, peer_id, peer_ip, peer_port, known_indexes}
    )
  end

  # -------------------------------------------------------------------------------
  # Utility Functions
  # -------------------------------------------------------------------------------
  @spec create_tracker_request(binary(), map()) :: binary()
  def create_tracker_request(url, params) do
    url_params =
      for key <- Map.keys(params),
          do: "#{key}" <> "=" <> "#{Map.get(params, key)}"

    URI.encode(url <> "?" <> Enum.join(url_params, "&"))
  end

  defp parse_tracker_response(body) do
    {status, track_resp} = Bento.decode(body)
    Logger.debug(fn -> "tracker response decode -> #{inspect(track_resp)}" end)

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
      :connected_peers,
      :no_peer_id,
      :next_piece_index,
      :numallowed,
      :peer_timer,
      :__struct__
    ]

    params =
      List.foldl(unwanted_params, data, fn elem, acc ->
        Map.delete(acc, elem)
      end)

    url = create_tracker_request(metadata.announce, params)
    # connect to tracker, respond based on what the http response is
    {status, resp} =
      @http_handle_impl.get(url, [], [
        {:timeout, 10_000},
        {:recv_timeout, 10_000}
      ])

    Logger.warn(fn -> "Response from tracker: #{inspect(resp)}" end)

    case status do
      :ok ->
        # response returns a text/plain object
        {status, tracker_info} = parse_tracker_response(resp.body)

        case status do
          :error ->
            {:reply, {:error, "Failed to connect to tracker"},
             {metadata, Map.put(data, :status, :error)}}

          _ ->
            # update data
            parsed_peers =
             tracker_info
             |> Map.get(:peers)
             |> parse_peers_binary()
             #[{{127,0,0,1}, 51413}]

            new_ttinfo =
              tracker_info
              |> Map.put(:peers, parsed_peers)

            updated_data =
              data
              |> Map.put(:tracker_info, new_ttinfo)
              |> Map.put(:status, :connected)

            {:reply, {:ok, {metadata, updated_data}}, {metadata, updated_data}}
        end

      :error ->
        Logger.error("Failed to fetch #{url}")
        Logger.error("Resp: #{inspect(resp)}")
        {:reply, {:error, "failed to fetch #{url}"}, {metadata, data}}
    end
  end

  defp create_initial_data(id, file, metadata) do
    info =
      metadata.info
      |> Map.from_struct()
      |> Map.delete(:md5sum)
      |> Map.delete(:private)
      |> BenEncoder.encode()
      |> IO.iodata_to_binary()

    hash = :crypto.hash(:sha, info)

    {:atomic, existing_data} =
      :mnesia.transaction(fn ->
        :mnesia.match_object({@torrent_cache_name, :_, file, :_, :complete, :_})
      end)

    piece_table =
      Enum.reduce(existing_data, %{}, fn {_table, _id, _file, index, status,
                                          _buff},
                                         acc ->
        Map.put(acc, index, {status, 0, <<>>})
      end)

    completed_indexes = Map.keys(piece_table)

    Logger.info(
      "#{file} is starting with the following complete pieces: #{
        inspect(completed_indexes)
      }"
    )

    num_pieces =
      metadata.info.pieces
      |> pack_piece_list()
      |> length()

    ret_data = %TorrentData{
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
      # TODO: ALLOW THIS TO GRAB MORE PEERS THEN NECESSARY?
      numwant: Application.fetch_env!(:bittorrent_client, :numwant),
      numallowed:
        Application.fetch_env!(:bittorrent_client, :allowedconnections),
      key: Application.fetch_env!(:bittorrent_client, :key),
      trackerid: "",
      tracker_info: %TrackerInfo{},
      pieces: piece_table,
      num_pieces: num_pieces,
      next_piece_index: 0,
      connected_peers: %{}
    }

    if length(completed_indexes) == num_pieces do
      Logger.debug(fn -> "I am here" end)
      handle_complete_data({metadata, ret_data})
    end

    {:ok, ret_data}
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

  @spec add_single_piece(
          peer_id :: binary(),
          index :: integer(),
          piece_table :: map()
        ) :: {:ok, map()} | {:error, binary()}
  defp add_single_piece(_peer_id, index, _piece_table) when index < 0 do
    {:error, "Invalid index #{index}"}
  end

  defp add_single_piece(_peer_id, index, piece_table) do
    if Map.has_key?(piece_table, index) do
      {status, ref_count, buff} = Map.get(piece_table, index)
      {:ok, Map.put(piece_table, index, {status, ref_count + 1, buff})}
    else
      {:ok, Map.put(piece_table, index, {:found, 1, <<>>})}
    end
  end

  @spec remove_ref_from_single_piece(map(), integer()) ::
          {:ok, map()} | {:error, binary()}
  defp remove_ref_from_single_piece(piece_table, index) do
    if Map.has_key?(piece_table, index) do
      {status, ref_count, buff} = Map.get(piece_table, index)

      if status == :found and ref_count == 1 do
        {:ok, Map.delete(piece_table, index)}
      else
        {:ok, Map.put(piece_table, index, {status, ref_count - 1, buff})}
      end
    else
      {:error, "#{index} does not exist in given piece table"}
    end
  end

  defp start_torrent_helper(id, {metadata, data}) do
    peer_list_t =
      data.tracker_info.peers
      |> Enum.shuffle()

    peer_list = peer_list_t |> Enum.take(data.numallowed)
    new_peer_list = peer_list_t |> Enum.drop(data.numallowed)
    new_ttinfo = %TrackerInfo{data.tracker_info | peers: new_peer_list}

    case peer_list do
      [] ->
        Logger.warn("#{id} has no available peers")

        # TODO: RECONNECT TO TRACKER FOR MORE PEERS

        {:reply, {:error, {403, "#{id} has no available peers"}},
         {metadata, data}}

      _ ->
        returned_pids = connect_to_peers(peer_list, {metadata, data})
        Logger.debug(fn -> "returned pids: #{inspect(returned_pids)}" end)
        # start process callback here to continously check peer numbers
        timer = :erlang.start_timer(@peer_check_interval, self(), :peer_check)

        {:reply, {:ok, "started torrent #{id}", returned_pids},
         {metadata,
          %TorrentData{
            data
            | status: :started,
              tracker_info: new_ttinfo,
              peer_timer: timer
          }}}
    end
  end

  @spec connect_to_peers(
          [PeerData.peerConnection()],
          {TorrentMetainfo.t(), TorrentData.t()}
        ) :: [pid()]
  defp connect_to_peers(peer_list, {metadata, data}) do
    Enum.map(peer_list, fn {ip, port} ->
      spawn(fn ->
        PeerSupervisor.start_child(
          {metadata, data.id, data.info_hash, data.file,
           data.tracker_info.interval, ip, port}
        )
      end)
    end)
  end

  defp pack_piece_list(piece_bin) do
    num_bits = @piece_hash_length * 8

    for <<single_hash::size(num_bits) <- piece_bin>>,
      do: <<single_hash::size(num_bits)>>
  end

  @spec validate_piece([<<_::20>>], integer(), binary()) ::
          {boolean(), binary()}
  defp validate_piece(pieces_hashes, piece_index, piece_buff) do
    expected = Enum.at(pieces_hashes, piece_index)

    actual =
      piece_buff
      |> (fn x -> :crypto.hash(:sha, x) end).()

    {expected == actual, actual}
  end

  defp handle_complete_data({metadata, data}) do
    file = "#{@destination_dir}#{metadata.info.name}"

    if File.exists?(file) == false do
      Logger.info("#{file} is complete, assembling the file")

      spawn(fn ->
        FileAssembler.assemble_file({metadata, data})
      end)
    end
  end

  defp handle_stopping_all_peers([]) do
    :ok
  end

  defp handle_stopping_all_peers([pid | rst]) do
    if Process.alive?(pid) do
      Process.exit(:terminate, pid)
    else
      Logger.warn("Somehow lost track of pid")
    end

    handle_stopping_all_peers(rst)
  end
end
