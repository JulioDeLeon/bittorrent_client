defmodule BittorrentClient.Server.Worker do
  @moduledoc """
  BittorrentClient Server handles calls to add or remove new torrents to be handle,
  control to torrent handlers and database modules
  """
  use GenServer
  require Logger
  alias BittorrentClient.Torrent.Supervisor, as: TorrentSupervisor
  alias BittorrentClient.Torrent.Worker, as: TorrentWorker
  alias BittorrentClient.Torrent.Data, as: TorrentData

  def start_link(db_dir, name) do
    Logger.info fn -> "Starting BTC server for #{name}" end
    GenServer.start_link(
      __MODULE__,
      {db_dir, name, Map.new()},
      name: {:global, {:btc_server, name}}
    )
  end

  def init({db_dir, name, torrent_map}) do
    # load from database into table
    {:ok, {db_dir, name, torrent_map}}
  end

  def whereis(name) do
    :global.whereis_name({:btc_server, name})
  end

  def list_current_torrents(serverName) do
    Logger.info fn -> "Entered list_current_torrents" end
    GenServer.call(:global.whereis_name({:btc_server, serverName}),
      {:list_current_torrents})
  end

  def add_new_torrent(serverName, torrentFile) do
    Logger.info fn -> "Entered add_new_torrent #{torrentFile}" end
    GenServer.call(:global.whereis_name({:btc_server, serverName}),
      {:add_new_torrent, torrentFile})
  end

  def connect_torrent_to_tracker(serverName, id) do
    Logger.info fn -> "Entered connect_torrent_to_tracker #{id}" end
    GenServer.call(:global.whereis_name({:btc_server, serverName}),
      {:connect_to_tracker, id})
  end

  def get_torrent_info_by_id(serverName, id) do
    Logger.info fn -> "Entered get_torrent_info_by_id #{id}" end
    GenServer.call(:global.whereis_name({:btc_server, serverName}),
      {:get_info_by_id, id})
  end

  def delete_torrent_by_id(serverName, id) do
    Logger.info fn -> "Entered delete_torrent_by id #{id}" end
    GenServer.call(:global.whereis_name({:btc_server, serverName}),
      {:delete_by_id, id})
  end

  def update_torrent_status_by_id(serverName, id, status) do
    Logger.info fn -> "Entered update_torrent_status_by_id" end
    GenServer.call(:global.whereis_name({:btc_server, serverName}),
      {:update_by_id, id, status})
  end

  def delete_all_torrents(serverName) do
    Logger.info fn -> "Entered delete_all_torrents" end
    GenServer.call(:global.whereis_name({:btc_server, serverName}),
      {:delete_all})
  end

  def handle_call({:list_current_torrents}, _from, {db, serverName, torrents}) do
    {:reply, {:ok, torrents}, {db, serverName, torrents}}
  end

  def handle_call({:get_info_by_id, id}, _from, {db, serverName, torrents}) do
    if Map.has_key?(torrents, id) do
      {:reply, {:ok, Map.fetch(torrents, id)}, {db, serverName, torrents}}
    else
      {:reply, {:error, "Bad ID was given"}, {db, serverName, torrents}}
    end
  end

  def handle_call({:add_new_torrent, torrentFile}, _from, {db, serverName, torrents}) do
    # TODO: add some salt
    id = torrentFile
    |> fn x -> :crypto.hash(:md5, x) end.()
    |> Base.encode32
    Logger.debug fn -> "add_new_torrent Generated #{id}" end
    if not Map.has_key?(torrents, id) do
      {status, _} = TorrentSupervisor.start_child({id, torrentFile})
      Logger.debug fn -> "add_new_torrent Status: #{status}" end
      case status do
        :error ->
          {:reply, {:error, "Failed to add torrent for #{torrentFile}"},
           {db, serverName, torrents}}
      	_ ->
          {check, data} = TorrentWorker.get_torrent_data(id)
          case check do
          	:error ->
              Logger.error fn -> "Failed to add new torrent for #{torrentFile}" end
              {:reply, {:error, "Failed to add torrent"}, {db, serverName, torrents}}
          	_ ->
              updated_torrents = Map.put(torrents, id, data)
              {:reply, {:ok, id}, {db, serverName, updated_torrents}}
          end
      end
    else
        {:reply, {:error, "That torrent already exist, Here's the ID: #{id}"},
         {db, serverName, torrents}}
    end
  end

  def handle_call({:delete_by_id, id}, _from, {db, serverName, torrents}) do
    Logger.debug fn -> "Entered delete_by_id" end
    if Map.has_key?(torrents, id) do
      torrent_data = Map.get(torrents, id)
      Logger.debug fn -> "TorrentData: #{inspect torrent_data}" end
      TorrentSupervisor.terminate_child(torrent_data.pid)
      torrents = Map.delete(torrents, id)
      {:reply, {:ok, id}, {db, serverName, torrents}}
    else
      {:reply, {:error, "Bad ID was given"}, {db, serverName, torrents}}
    end
  end

  def handle_call({:connect_to_tracker, id}, _from, {db, serverName, torrents}) do
    Logger.info fn -> "Entered callback of connect_to_trakcer" end
    if Map.has_key?(torrents, id) do
      {status, msg} = TorrentWorker.connect_to_tracker(id)
      case status do
        :error ->
          {:reply, {:error, msg}, {db, serverName, torrents}}
        _ ->
          updated_torrents = Map.put(torrents, id, TorrentWorker.get_torrent_data(id))
          {:reply, {:ok, "#{id} has connected to tracker"}, {db, serverName, updated_torrents}}
      end
   else
      {:reply, {:error, "Bad ID was given"}, {db, serverName, torrents}}
    end
  end

  def handle_call({:update_by_id, id, status}, _from, {db, serverName, torrents}) do
    if Map.has_key?(torrents, id) do
      torrents = Map.update!(torrents, id,
        fn dataPoint -> %TorrentData{dataPoint | status: status} end)
      {:reply, {:ok, torrents}, {db, serverName, torrents}}
    else
      {:reply, {:error, "Bad ID was given"}, {db, serverName, torrents}}
    end
  end

  def handle_call({:delete_all}, _from, {db, serverName, torrents}) do
    torrents = Map.drop(torrents, Map.keys(torrents))
    {:reply, {:ok, torrents}, {db, serverName, torrents}}
  end
end
