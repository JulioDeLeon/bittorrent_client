defmodule BittorrentClient.WebSupervisor do
  def start_link do
    import Supervisor.Spec

    IO.puts "Starting Web Supervisor"
    children = [
      Plug.Adapters.Cowboy.child_spec(:http, BittorrentClient.Web, [], [port: 4000])
    ]

    opts = [strategy: :one_for_one, name: BittorrentClient.WebSupervisor]
    Supervisor.start_link(children, opts)
  end
end
