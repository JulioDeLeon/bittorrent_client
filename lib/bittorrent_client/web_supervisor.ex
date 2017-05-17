defmodule BittorrentClient.WebSupervisor do
  @moduledoc """
  WebSupervisor supervises the Web module of BittorrentClient
  """
  require Logger
  alias Plug.Adapters.Cowboy, as: Cowboy

  def start_link do
    #import Supervisor.Spec

    Logger.info "Starting Web Supervisor"
    children = [
      Cowboy.child_spec(:http, BittorrentClient.Web, [], [port: 8080])
    ]

    opts = [strategy: :one_for_one, name: BittorrentClient.WebSupervisor]
    Supervisor.start_link(children, opts)
  end
end
