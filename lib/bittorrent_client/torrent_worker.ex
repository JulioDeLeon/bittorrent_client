defmodule BittorrentClient.TorrentWorker do
  use GenServer

  def start_link(filename) do
    IO.puts "Starting torrent worker for #{filename}"
    GenServer.start_link(
      __MODULE__,
      filename,
      name: {:global, {BittorrentClient.TorrentWorker, filename}}
    )    
  end
  # handle_call
  # handle_cast
  def init(filename) do
    IO.puts "Opening #{filename}"
    {:ok, filename}
  end
end
