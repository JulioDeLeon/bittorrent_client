defmodule BittorrentClient.Supervisor do
  @moduledoc """
  BittorrentClient Supervisor watches over all relevant threads to BittorrentClient application
  """
  use Supervisor

  alias BittorrentClient.Server.Supervisor, as: ServerSupervisor
  alias BittorrentClient.Web.Supervisor, as: WebSupervisor
  alias BittorrentClient.Torrent.Supervisor, as: TorrentSupervisor
  alias BittorrentClient.Peer.Supervisor, as: PeerSupervisor
  @server_name Application.get_env(:bittorrent_client, :server_name)

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      worker(ServerSupervisor, [@server_name]),
      worker(WebSupervisor, []),
      worker(TorrentSupervisor, []),
      worker(PeerSupervisor, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
