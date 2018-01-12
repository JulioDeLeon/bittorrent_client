defmodule BittorrentClient do
  @behaviour Application
  @moduledoc """
  BittorrentClient is a torrent client written in Elixir. This module is the entry point of the application
  """
  def start(_type \\ [], _args \\ []) do
    BittorrentClient.Supervisor.start_link()
  end

  def stop(_) do
    Application.stop(__MODULE__)
  end
end
