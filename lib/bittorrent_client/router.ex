defmodule BittorrentClient.Router do 
  use Plug.Router

  plug Plug.Logger
  plug :match
  plug :dispatch

  get "/ping" do
    send_resp(conn, 200, "pong")
  end

  # Forwards to other routers here

  match _ do
    send_resp(conn, 404, "oops")
  end
end
