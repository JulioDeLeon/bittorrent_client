defmodule BittorrentClient.Server do
  use GenServer

  # start_link
  def start_link(db_dir, name) do
    IO.puts "Starting BTC server for #{name}"
    GenServer.start_link(
      __MODULE__,
      db_dir,
      name: {:global, {BittorrentClient.Server, name}}
    )
  end
  # handle_call
  # handle_cast
end
