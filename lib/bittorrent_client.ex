defmodule BittorrentClient do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      Plug.Adapters.Cowboy.child_spec(:http, BittorrentRouter, [], [port: 4000])
    ]

    opts = [strategy: :one_for_one, name: BittorrentClient.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
