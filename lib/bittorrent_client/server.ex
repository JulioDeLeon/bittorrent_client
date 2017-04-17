defmodule BittorrentClient.Server do
  use GenServer
  @moduledoc """
  BittorrentClient Server handles calls to add or remove new torrents to be handle,
  control to torrent handlers and database modules
  """

  def start_link(db_dir, name) do
    IO.puts "Starting BTC server for #{name}"
    GenServer.start_link(
      __MODULE__,
      {db_dir, name, Map.new()},
      name: {:global, {:btc_server, name}}
    )
  end

  def init({db_dir, name, torrent_map}) do
    {:ok, {db_dir, name, torrent_map}}
  end

  def whereis(name) do
    :global.whereis_name({:btc_server, name})
  end

  def list_current_torrents(serverName) do
    IO.puts "Entered list_current_torrents"
    GenServer.call(:global.whereis_name({:btc_server, serverName}),
      {:list_current_torrents})
  end

  def add_new_torrent(serverName, torrentFile) do
    IO.puts "Entered add_new_torrent #{torrentFile}"
    GenServer.call(:global.whereis_name({:btc_server, serverName}),
      {:add_new_torrent, torrentFile})
  end

  def delete_torrent_by_id(serverName, id) do
    IO.puts "Entered delete_torrent_by id #{id}"
    GenServer.call(:global.whereis_name({:btc_server, serverName}),
      {:delete_by_id, id})
  end

  def update_torrent_status_by_id(serverName, id, status) do
    IO.puts "Entered update_torrent_status_by_id"
    GenServer.call(:global.whereis_name({:btc_server, serverName}),
      {:update_by_id, id, status})
  end

  def delete_all_torrents(serverName) do
    IO.puts "Entered delete_all_torrents"
    GenServer.call(:global.whereis_name({:btc_server, serverName}),
      {:delete_all})
  end

  def handle_call({:list_current_torrents}, _from, {db, serverName, torrents}) do
    {:reply, torrents, {db, serverName, torrents}}
   # {status, actions, new state}
  end

  def handle_call({:add_new_torrent, torrentFile}, _from, {db, serverName, torrents}) do
    id = torrentFile
    |> fn x -> :crypto.hash(:md5, x) end.()
    |> Base.encode32

    if not Map.has_key?(torrents, id) do
      torrents = Map.put(torrents, id, {torrentFile, "init"})
      {:reply, torrents, {db, serverName, torrents}}
    else
      {:reply, "That torrent already exist", {db, serverName, torrents}}
    end
  end

  def handle_call({:delete_by_id, id}, _from, {db, serverName, torrents}) do
    if Map.has_key?(torrents, id) do
      torrents = Map.delete(torrents, id)
      {:reply, torrents, {db, serverName, torrents}}
    else
      {:reply, "Bad ID was given", {db, serverName, torrents}}
    end
  end

  def handle_call({:update_by_id, id, status}, _from, {db, serverName, torrents}) do
    if Map.has_key?(torrents, id) do
      torrents = Map.update!(torrents, id, fn {file, _} -> {file, status} end)
      {:reply, torrents, {db, serverName, torrents}}
    else
      {:reply, "Bad ID was given", {db, serverName, torrents}}
    end
  end

  def handle_call({:delete_all}, _from, {db, serverName, torrents}) do
    torrents = Map.drop(torrents, Map.keys(torrents))
    {:reply, torrents, {db, serverName, torrents}}
  end
end
