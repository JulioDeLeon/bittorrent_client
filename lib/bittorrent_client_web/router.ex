defmodule BittorrentClientWeb.Router do
  use BittorrentClientWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", BittorrentClientWeb do
    # Use the default browser stack
    pipe_through(:browser)

    get("/", PageController, :index)
  end

  # Other scopes may use custom stacks.
  scope "/api/v1", BittorrentClientWeb do
    pipe_through(:api)

    get("/ping", TorrentController, :ping)
    get("/torrent/:id/status", TorrentController, :status)
    get("/torrent/:id/info", TorrentController, :info)
    put("/torrent/:id/connect", TorrentController, :connect)
    put("/torrent/:id/connect/async", TorrentController, :connect_async)
    put("/torrent/:id/startTorrent", TorrentController, :start_torrent)

    put(
      "/torrent/:id/startTorrent/async",
      TorrentController,
      :start_torrent_async
    )

    post("/torrent/addFile", TorrentController, :add_file)
    delete("/torrent/:id/remove", TorrentController, :delete_torrent)
    get("/torrent", TorrentController, :all)
    delete("/torrent/removeAll", TorrentController, :remove_all)
  end
end
