defmodule BittorrentClientWeb.Router do
  use BittorrentClientWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BittorrentClientWeb do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  scope "/api/v1", BittorrentClientWeb do
    pipe_through :api

    get "/ping", TorrentController, :ping
    get "/:id/status", TorrentController, :status
    get "/:id/info", TorrentController, :info
    put "/:id/connect", TorrentController, :connect
    put "/:id/connect/async", TorrentController, :connect_async
    put "/:id/startTorrent", TorrentController, :start_torrent
    put "/:id/startTorrent/async", TorrentController, :start_torrent_sync
    post "/addFile", TorrentController, :add_file
    delete "/:id/remove", TorrentController, :delete_torrent
    get "/all", TorrentController, :all
    delete "/removeAll", TorrentController, :remove_all
  end
end
