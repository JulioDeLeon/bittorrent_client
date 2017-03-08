defmodule BittorrentClient.Router do 
  use Plug.Router

  plug Plug.Logger
  plug Plug.Parsers, parsers: [:urlencoded, :json],
                     pass: ["text/*"],
                     json_decoder: Poison
  plug :match
  plug :dispatch

  defp parse(conn, opts \\ []) do
    opts = opts
           |> Keyword.put_new(:parsers, [:json])
           |> Keyword.put_new(:json_decoder, Poison)
    Plug.Parsers.call(conn, Plug.Parsers.init(opts))
  end

  get "/ping" do
    send_resp(conn, 200, "pong")
  end

  # simple example of a request parameter
  get "/request/:id" when byte_size(id) >= 3 do
    IO.puts Enum.join(["Received the following ID: ", id])
    send_resp(conn, 200, Enum.join(["Returning: ", id, "\n"]))
  end

  # simple post request example
  post "/requestPost" do
    conn = parse(conn, Plug.Parsers.JSON)
    id = conn.params["id"]
    IO.puts Enum.join(["The body params: ", inspect conn.body_params])
    send_resp(conn, 200, "hit\n")
  end

  match _ do
    send_resp(conn, 404, "oops")
  end
end
