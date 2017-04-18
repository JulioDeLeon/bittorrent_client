defmodule BittorrentClient.Web do
  @moduledoc """
  Web module defines the RESTful api to interact with BittorrentClient
  """
  use Plug.Router
  alias Plug.Conn, as: Conn

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
    conn = Conn.fetch_query_params(conn)
    # Once the payload is parsed, can kick off and handle things accordingly
    term = conn.params["term"]
    IO.puts Enum.join(["Received the following term: ", term])
    send_resp(conn, 200, Enum.join(["Returning: ", term, "\n"]))
  end

  # example of a put request
  put "/requestPut" do
    conn = Conn.fetch_query_params(conn)
    # Once the payload is parsed, can kick off and handle things accordingly
    term = conn.params["term"]
    IO.puts Enum.join(["Received the following term: ", term])
    send_resp(conn, 200, Enum.join(["Returning: ", term, "\n"]))
  end

  @api_root "/api/v1"

  get "#{@api_root}/:id/status" when byte_size(id) > 3 do
    IO.puts Enum.join(["Received the following ID: ", id])
    send_resp(conn, 200, Enum.join(["Returning: ", id, "\n"]))
  end

  post "#{@api_root}/add/file" do
    conn = Conn.fetch_query_params(conn)
    filename = conn.params["filename"]
    IO.puts "Received the following filename: #{filename}"
	{status, data} = BittorrentClient.Server.add_new_torrent("GenericName", filename)
    case status do
      :ok -> send_resp(conn, 200, data)
      :error -> send_resp(conn, 400, data)
      _ -> send_resp(conn, 500, "Don't know what happened")
    end
  end

  post "#{@api_root}/remove/id" do
    conn = Conn.fetch_query_params(conn)
    id = conn.params["id"]
    IO.puts "Received the following filename: #{id}"
	{status, data} = BittorrentClient.Server.delete_torrent_by_id("GenericName", id)
    case status do
      :ok -> send_resp(conn, 200, data)
      :error -> send_resp(conn, 400, data)
      _ -> send_resp(conn, 500, "Don't know what happened")
    end
  end

  match _ do
    send_resp(conn, 404, "oops")
  end

end
