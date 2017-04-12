defmodule BittorrentClient.Server do
  use GenServer

  def start_link(db_dir, name) do
    IO.puts "Starting BTC server for #{name}"
    GenServer.start_link(
      __MODULE__,
      {db_dir, name},
      name: {:global, {:btc_server, name}}
    )
  end

  def init({db_dir, name}) do
    {:ok, {db_dir, name}}
  end

  def whereis(name) do
    :global.whereis_name({:btc_server, name})
  end

  def list_current_torrents(serverName) do
    IO.puts "Entered list_current_torrents"
    GenServer.call(:global.whereis_name({:btc_server, serverName}), {:list_current_torrents})
  end

  def add_new_torrent(torrentFile) do
    IO.puts "Entered add_new_torrent #{torrentFile}"
  end

  def delete_torrent_by_id(id) do
    IO.puts "Entered delete_torrent_by id #{id}"
  end

  # handle_call
  def handle_call({:list_current_torrents}, _from, {db, serverName}) do
    {:reply, :ok, serverName}
                 #do things here
  end

  # handle_cast
end
