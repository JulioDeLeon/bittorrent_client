defmodule BittorrentClient.Router do 
  use Plug.Router

  plug Plug.Logger
  plug Plug.Parsers, parsers: [:urlencoded, :json],
                     pass: ["text/*"],
                     json_decoder: Poison
  plug :match
  plug :dispatch

  get "/ping" do
    send_resp(conn, 200, "pong")
  end

  # simple example of a request parameter
  get "/request/:id" when byte_size(id) >= 3 do
    IO.puts Enum.join(["Received the following ID: ", id])
    send_resp(conn, 200, Enum.join(["Returning: ", id, "\n"]))
  end

  # simple post request example
  # this can only hanlde JSON payloads
  post "/requestPost" do
    conn = Plug.Conn.fetch_query_params(conn)
    # Once the payload is parsed, can kick off and handle things accordingly
    term = conn.params["term"]
    IO.puts Enum.join(["Received the following term: ", term])
    send_resp(conn, 200, Enum.join(["Returning: ", term, "\n"]))
  end

  # example of a put request
  put "/requestPut" do
    conn = Plug.Conn.fetch_query_params(conn)
    # Once the payload is parsed, can kick off and handle things accordingly
    term = conn.params["term"]
    IO.puts Enum.join(["Received the following term: ", term])
    send_resp(conn, 200, Enum.join(["Returning: ", term, "\n"]))
  end

  match _ do
    send_resp(conn, 404, "oops")
  end
end
