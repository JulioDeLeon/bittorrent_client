defmodule BittorrentClient do
  use Application

  def start(_type, _args) do
    BittorrentClient.ServerSupervisor.start_link()
    BittorrentClient.WebSupervisor.start_link()
    BittorrentClient.Database.start_link("./")
  end
end
