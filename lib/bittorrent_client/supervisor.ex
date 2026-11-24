defmodule BittorrentClient.Supervisor do
  @moduledoc """
  BittorrentClient Supervisor watches over all relevant threads to BittorrentClient application
  """
  use Supervisor

  alias BittorrentClient.Peer.Supervisor, as: PeerSupervisor
  alias BittorrentClient.Server.Supervisor, as: ServerSupervisor
  alias BittorrentClient.Torrent.Supervisor, as: TorrentSupervisor
  alias BittorrentClient.Web.Supervisor, as: WebSupervisor
  @server_name Application.compile_env(:bittorrent_client, :server_name)

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      %{
        id: ServerSupervisor,
        start: {ServerSupervisor, :start_link, ["priv/output/", @server_name]},
        type: :supervisor
      },
      %{
        id: WebSupervisor,
        start: {WebSupervisor, :start_link, []},
        type: :supervisor
      },
      %{
        id: TorrentSupervisor,
        start: {TorrentSupervisor, :start_link, []},
        type: :supervisor
      },
      %{
        id: PeerSupervisor,
        start: {PeerSupervisor, :start_link, []},
        type: :supervisor
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
