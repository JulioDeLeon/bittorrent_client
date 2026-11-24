defmodule BittorrentClient.Server.Supervisor do
  @moduledoc """
  ServerSupervisor supervises BittorrentClient Server
  """
  use Supervisor
  require Logger
  @server_impl Application.compile_env(:bittorrent_client, :server_impl)

  def start_link(destination, name) do
    Logger.info("Starting Server Supervisor")
    Supervisor.start_link(__MODULE__, [destination, name], name: __MODULE__)
  end

  def init([dest, name]) do
    children = [
      %{
        id: {:server, name},
        start: {@server_impl, :start_link, [dest, name]}
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
