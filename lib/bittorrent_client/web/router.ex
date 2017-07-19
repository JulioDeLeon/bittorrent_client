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

  # though this is usefull for curl, for UI, send put request to the UI service to get updates
  get "#{@api_root}/:id/status" when byte_size(id) > 3 do
    Logger.info fn -> "Getting status for #{id}" end
    {status, msg} = Server.get_torrent_info_by_id("GenericName", id)
    case status do
      :ok ->
        Logger.debug fn -> "Retrieved info for #{id}" end
        put_resp_content_type(conn, "application/json")
        data = msg["data"]
        send_resp(conn, 200, %{"status" => Map.get(data, :status),
                               "downloaded" => Map.get(data, :downloaded),
                               "uploaded" => Map.get(data, :uploaded)}
          |> Poison.encode!())
      :error ->
        Logger.debug fn -> "Failed to retrieve info for #{id}" end
        {code, err_msg} = msg
        send_resp(conn, code, err_msg)
    end
  end

  get "#{@api_root}/:id/info" when byte_size(id) > 3 do
    Logger.info fn -> "Getting info for #{id}" end
    {status, msg} = Server.get_torrent_info_by_id("GenericName", id)
    case status do
      :ok ->
        Logger.debug fn -> "Retrieved info for #{id}" end
        put_resp_content_type(conn, "application/json")
        send_resp(conn, 200, msg |> entry_to_encodable() |> Poison.encode!())
      :error ->
        Logger.debug fn -> "Failed to retrieve info for #{id}" end
        {code, err_msg} = msg
        send_resp(conn, code, err_msg)
    end
  end

  put "#{@api_root}/:id/connect" when byte_size(id) > 3 do
    Logger.info fn -> "Connecting #{id} to tracker" end
    {status, msg} = Server.connect_torrent_to_tracker("GenericName", id)
    case status do
      :error ->
        Logger.debug fn -> "connect returning error" end
        {code, err_msg} = msg
        send_resp(conn, code, err_msg)
      :ok ->
        Logger.debug fn -> "connect returning success" end
        send_resp(conn, 204, "")
    end
  end

  post "#{@api_root}/add/file" do
    conn = Conn.fetch_query_params(conn)
    filename = conn.params["filename"]
    Logger.info fn -> "Received the following filename: #{filename}" end
    {status, data} = Server.add_new_torrent("GenericName", filename)
    case status do
      :ok ->
        put_resp_content_type(conn, "application/json")
        send_resp(conn, 200, Poison.encode!(data))
      :error ->
        {code, err_msg} = data
        send_resp(conn, code, err_msg)
    end
  end

  delete "#{@api_root}/:id/remove" when byte_size(id) > 3 do
    # TODO: NOT TESTED YET
    Logger.info fn -> "Received the following filename: #{id}" end
    {status, data} = Server.delete_torrent_by_id("GenericName", id)
    case status do
      :ok -> send_resp(conn, 200, data)
      _ -> send_resp(conn, 500, "Don't know what happened")
    end
  end

  get "#{@api_root}/all" do
  	{status, data} = Server.list_current_torrents("GenericName")
    case status do
      :ok ->
        ret = Enum.reduce(Map.keys(data), %{}, fn (key, acc) ->
        val = Map.get(data, key)
        Map.put(acc, key, entry_to_encodable(val))end)
        put_resp_content_type(conn, "application/json")
        send_resp(conn, 200, Poison.encode!(ret))
      :error -> send_resp(conn, 500, "Couldn't get all torrents")
    end
  end

  delete "#{@api_root}/remove/all" do
    # TODO: NOT TESTED YET
    {status, _} = Server.delete_all_torrents("GenericName")
    case status do
      :ok -> send_resp(conn, 204, "")
      :error -> send_resp(conn, 500, "Something went wrong")
    end
  end

  match _ do
    send_resp(conn, 404, "oops")
  end

  defp entry_to_encodable(data_point) do
    # this function is created to work with Bento.Metainfo module to encode as json
    {_, new_dp} = data_point
    |> Map.get_and_update("metadata", fn  metadata ->
      {data_point, fn ->
        {_, new_md} = metadata
        |> Map.from_struct()
        |> Map.get_and_update(:info, fn info ->
          {metadata, info |> Map.from_struct() |> Map.delete(:pieces)}
        end)
        new_md
      end.()}
    end)
    new_dp
  end
end
