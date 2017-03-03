defmodule BittorrentRouter do 
  use Plug.Router
  
  plug :match
  plug :dispatch
  
  get "/ping" do
    send_resp(conn, 200, "ping")
  end

  match _ do
    send_resp(conn, 404, "oops")
  end
end
