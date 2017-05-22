defmodule BittorrentClient.Supervisor do
  @moduledoc """
  BittorrentClient Supervisor watches over all relevant threads to BittorrentClient application
  """
  use Supervisor

  alias BittorrentClient.ServerSupervisor, as: ServerSupervisor
  alias BittorrentClient.WebSupervisor, as: WebSupervisor
  alias BittorrentClient.TorrentSupervisor, as: TorrentSupervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      worker(ServerSupervisor, []),
      worker(WebSupervisor, []),
      worker(TorrentSupervisor, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
