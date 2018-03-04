defmodule BittorrentClient.Web.Supervisor do
  @moduledoc """
  WebSupervisor supervises the Web module of BittorrentClient
  """
  use Supervisor
  require Logger
  alias Plug.Adapters.Cowboy, as: Cowboy
  alias BittorrentClient.Web.Router, as: Router

  def start_link do
    Logger.info("Starting Web Supervisor")
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(_) do
    children = [
      Cowboy.child_spec(:http, Router, [], port: 8080)
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    supervise(children, opts)
  end
end
