defmodule BittorrentClient.Supervisor do
  @moduledoc """
  BittorrentClient Supervisor watches over all relevant threads to BittorrentClient application
  """
  use Supervisor

  alias BittorrentClient.Server.Supervisor, as: ServerSupervisor
  alias BittorrentClient.Web.Supervisor, as: WebSupervisor
  alias BittorrentClient.Torrent.Supervisor, as: TorrentSupervisor
  alias BittorrentClient.Peer.Supervisor, as: PeerSupervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      worker(ServerSupervisor, ["GenericName"]),
      worker(WebSupervisor, []),
      worker(TorrentSupervisor, []),
      worker(PeerSupervisor, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
