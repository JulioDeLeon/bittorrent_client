defmodule BittorrentClient.Web.Router do
  @moduledoc """
  Web module defines the RESTful api to interact with BittorrentClient
  """
  use Plug.Router
  alias Plug.Conn, as: Conn
  require Logger

  plug Plug.Logger
  plug Plug.Parsers, parsers: [:urlencoded, :json],
                     pass: ["text/*"],
                     json_decoder: Poison
  plug :match
  plug :dispatch

  alias BittorrentClient.Server.Worker, as: Server

  @api_root "/api/v1"

  get "/ping" do
    send_resp(conn, 200, "pong")
  end

  get "#{@api_root}/:id/status" when byte_size(id) > 3 do
    # TODO: get status of torrent by id
    Logger.info fn -> "Getting status for #{id}" end
    send_resp(conn, 200, "THIS ENDPOINT IS NOT FINISHED")
  end

  get "#{@api_root}/:id/info" when byte_size(id) > 3 do
    # TODO: change this to for new torrent info structure
    Logger.info fn -> "Getting info for #{id}" end
    # {status, ti} = Server.get_torrent_info_by_id("GenericName", id)
    send_resp(conn, 200, "THIS ENDPOINT IS NOT FINISHED")
  end

  put "#{@api_root}/:id/connect" when byte_size(id) > 3 do
    # TODO: change response payload to json
    Logger.info fn -> "Connecting #{id} to tracker" end
    {status, msg} = Server.connect_torrent_to_tracker("GenericName", id)
    case status do
      :error ->
        Logger.debug fn -> "connect returning error" end
        send_resp(conn, 500, msg)
      :ok ->
        Logger.debug fn -> "connect returning success" end
        send_resp(conn, 200, msg)
    end
  end

  post "#{@api_root}/add/file" do
    # TODO: change handle new torrent info structure
    conn = Conn.fetch_query_params(conn)
    filename = conn.params["filename"]
    Logger.info fn -> "Received the following filename: #{filename}" end
    {status, data} = Server.add_new_torrent("GenericName", filename)
    case status do
      :ok ->
        put_resp_content_type(conn, "application/json")
        send_resp(conn, 200, Poison.encode!(data))
      :error -> send_resp(conn, 400, data)
      _ -> send_resp(conn, 500, "Don't know what happened")
    end
  end

  delete "#{@api_root}/:id/remove" when byte_size(id) > 3 do
    # TODO: change to json payload
    Logger.info fn -> "Received the following filename: #{id}" end
    {status, data} = Server.delete_torrent_by_id("GenericName", id)
    case status do
      :ok -> send_resp(conn, 200, data)
      _ -> send_resp(conn, 500, "Don't know what happened")
    end
  end

  get "#{@api_root}/all" do
    # TODO: ensure that this handles new entry types in Server.Worker state table
  	{status, data} = Server.list_current_torrents("GenericName")
    case status do
      :ok ->
        put_resp_content_type(conn, "application/json")
        send_resp(conn, 200, Poison.encode!(data))
      _ -> send_resp(conn, 500, "Couldn't get all torrents")
    end
  end

  delete "#{@api_root}/remove/all" do
    # TODO: change to json payload 
    {status, _} = Server.delete_all_torrents("GenericName")
    case status do
      :ok -> send_resp(conn, 200, "All torrents deleted")
      :error -> send_resp(conn, 500, "Something went wrong")
    end
  end

  match _ do
    send_resp(conn, 404, "oops")
  end

end
