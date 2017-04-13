defmodule BittorrentClient.Server do
  use GenServer

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
    GenServer.call(:global.whereis_name({:btc_server, serverName}), {:list_current_torrents})
  end

  def add_new_torrent(serverName, torrentFile) do
    IO.puts "Entered add_new_torrent #{torrentFile}"
    GenServer.call(:global.whereis_name({:btc_server, serverName}), {:add_new_torrent, torrentFile})
  end

  def delete_torrent_by_id(serverName, id) do
    IO.puts "Entered delete_torrent_by id #{id}"
    GenServer.call(:global.whereis_name({:btc_server, serverName}), {:delete_by_id, id})
  end

  # handle_call
  def handle_call({:list_current_torrents}, _from, {db, serverName, torrents}) do
    {:reply, torrents, {db, serverName, torrents}}
   # {status, actions, new state}
  end

  def handle_call({:add_new_torrent, torrentFile}, _from, {db, serverName, torrents}) do
    random_id =:rand.uniform(1000)
    torrents = Map.put(torrents, random_id, {"torrentFile", "init"})
    {:reply, torrents, {db, serverName, torrents}}
  end

  def handle_call({:delete_by_id, id}, _from, {db, serverName, torrents}) do
    torrents = Map.delete(torrents, id)
    {:reply, torrents, {db, serverName, torrents}}
  end

  # handle_cast (asynchronous)
end
