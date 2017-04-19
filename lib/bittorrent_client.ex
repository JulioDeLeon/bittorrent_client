defmodule BittorrentClient do
  @behaviour Application
  @moduledoc """
  BittorrentClient is a torrent client written in Elixir. This module is the entry point of the application
  """
  alias BittorrentClient.ServerSupervisor, as: ServerSupervisor
  alias BittorrentClient.WebSupervisor, as: WebSupervisor

  def start(_type, _args) do
    ServerSupervisor.start_link()
    WebSupervisor.start_link()
  end

  def stop(_) do
    # ServerSupervisor.terminate("")
    # WebSupervisor.terminate()
    # Database.terminate()
  end
end
