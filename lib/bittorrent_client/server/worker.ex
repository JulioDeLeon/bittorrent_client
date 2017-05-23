defmodule BittorrentClient.Server.Worker do
  @moduledoc """
  BittorrentClient Server handles calls to add or remove new torrents to be handle,
  control to torrent handlers and database modules
  """
  use GenServer
  require Logger
  alias BittorrentClient.Torrent.Supervisor, as: TorrentSupervisor
  alias BittorrentClient.Torrent.Data, as: TorrentData

  def start_link(db_dir, name) do
    #Logger.info "Starting BTC server for #{name}"
    Logger.info "Starting BTC server for #{name}"
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

  # on terminate flush table

  def whereis(name) do
    :global.whereis_name({:btc_server, name})
  end

  def list_current_torrents(serverName) do
    Logger.info "Entered list_current_torrents"
    GenServer.call(:global.whereis_name({:btc_server, serverName}),
      {:list_current_torrents})
  end

  def add_new_torrent(serverName, torrentFile) do
    Logger.info "Entered add_new_torrent #{torrentFile}"
    GenServer.call(:global.whereis_name({:btc_server, serverName}),
      {:add_new_torrent, torrentFile})
  end

  def delete_torrent_by_id(serverName, id) do
    Logger.info "Entered delete_torrent_by id #{id}"
    GenServer.call(:global.whereis_name({:btc_server, serverName}),
      {:delete_by_id, id})
  end

  def update_torrent_status_by_id(serverName, id, status) do
    Logger.info "Entered update_torrent_status_by_id"
    GenServer.call(:global.whereis_name({:btc_server, serverName}),
      {:update_by_id, id, status})
  end

  def delete_all_torrents(serverName) do
    Logger.info "Entered delete_all_torrents"
    GenServer.call(:global.whereis_name({:btc_server, serverName}),
      {:delete_all})
  end

  def handle_call({:list_current_torrents}, _from, {db, serverName, torrents}) do
    {:reply, {:ok, torrents}, {db, serverName, torrents}}
    # {status, actions, new state}
  end

  def handle_call({:add_new_torrent, torrentFile}, _from, {db, serverName, torrents}) do
    id = torrentFile
    |> fn x -> :crypto.hash(:md5, x) end.()
    |> Base.encode32
    Logger.debug "add_new_torrent Generated #{id}"
    if not Map.has_key?(torrents, id) do
      {status, childpid} = TorrentSupervisor.start_child({id, torrentFile})
      Logger.debug "add_new_torrent Status: #{status}"
      if status == :error do
        {:reply, {:error, "Failed to start torrent for #{torrentFile}"},
         {db, serverName, torrents}}
      else
          torrents = Map.put(torrents, id,
            %TorrentData{file: torrentFile, id: id, pid: childpid, status: "init"})
          {:reply, {:ok, id}, {db, serverName, torrents}}
      end
    else
        {:reply, {:error, "That torrent already exist, Here's the ID: #{id}"},
         {db, serverName, torrents}}
    end
  end

  def handle_call({:delete_by_id, id}, _from, {db, serverName, torrents}) do
    Logger.debug "Entered delete_by_id"
    if Map.has_key?(torrents, id) do
      torrent_data = Map.get(torrents, id)
      Logger.debug "TorrentData: #{inspect torrent_data}"
      TorrentSupervisor.terminate_child(torrent_data.pid)
      torrents = Map.delete(torrents, id)
      {:reply, {:ok, id}, {db, serverName, torrents}}
    else
      {:reply, {:error, "Bad ID was given"}, {db, serverName, torrents}}
    end
  end

  def handle_call({:update_by_id, id, status}, _from, {db, serverName, torrents}) do
    if Map.has_key?(torrents, id) do
      torrents = Map.update!(torrents, id,
        fn dataPoint -> %TorrentData{dataPoint | status: status} end)
      {:reply, torrents, {db, serverName, torrents}}
    else
      {:reply, "Bad ID was given", {db, serverName, torrents}}
    end
  end

  def handle_call({:delete_all}, _from, {db, serverName, torrents}) do
    torrents = Map.drop(torrents, Map.keys(torrents))
    {:reply, {:ok, torrents}, {db, serverName, torrents}}
  end
end
