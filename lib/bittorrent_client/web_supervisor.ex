defmodule BittorrentClient.WebSupervisor do
  @moduledoc """
  WebSupervisor supervises the Web module of BittorrentClient
  """
  alias Plug.Adapters.Cowboy, as: Cowboy

  def start_link do
    #import Supervisor.Spec

    IO.puts "Starting Web Supervisor"
    children = [
      Cowboy.child_spec(:http, BittorrentClient.Web, [], [port: 4000])
    ]

    opts = [strategy: :one_for_one, name: BittorrentClient.WebSupervisor]
    Supervisor.start_link(children, opts)
  end
end
