defmodule BittorrentClient.Web.Router do
  @moduledoc """
  Web module defines the RESTful api to interact with BittorrentClient
  """
  use Plug.Router
  alias Plug.Conn, as: Conn

  plug(Plug.Logger)

  plug(
    Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["text/*"],
    json_decoder: Poison
  )

  plug(:match)
  plug(:dispatch)

  alias BittorrentClient.Logger.Factory, as: LoggerFactory
  alias BittorrentClient.Logger.JDLogger, as: JDLogger

  @server_name Application.get_env(:bittorrent_client, :server_name)
  @server_impl Application.get_env(:bittorrent_client, :server_impl)
  @logger LoggerFactory.create_logger(__MODULE__)
  @api_root "/api/v1"

  get "/ping" do
    send_resp(conn, 200, "pong")
  end

  get "#{@api_root}/:id/status" when byte_size(id) > 3 do
    JDLogger.info(@logger, "Getting status for #{id}")
    {status, msg} = @server_impl.get_torrent_info_by_id(@server_name, id)

    case status do
      :ok ->
        JDLogger.debug(@logger, "Retrieved info for #{id}")
        put_resp_content_type(conn, "application/json")
        data = msg["data"]

        send_resp(
          conn,
          200,
          %{
            "status" => Map.get(data, :status),
            "downloaded" => Map.get(data, :downloaded),
            "uploaded" => Map.get(data, :uploaded)
          }
          |> Poison.encode!()
        )

      :error ->
        JDLogger.debug(@logger, "Failed to retrieve info for #{id}")
        {code, err_msg} = msg
        send_resp(conn, code, err_msg)
    end
  end

  get "#{@api_root}/:id/info" when byte_size(id) > 3 do
    JDLogger.info(@logger, "Getting info for #{id}")
    {status, msg} = @server_impl.get_torrent_info_by_id(@server_name, id)

    case status do
      :ok ->
        JDLogger.debug(@logger, "Retrieved info for #{id}")
        put_resp_content_type(conn, "application/json")
        send_resp(conn, 200, msg |> entry_to_encodable() |> Poison.encode!())

      :error ->
        JDLogger.debug(@logger, "Failed to retrieve info for #{id}")
        {code, err_msg} = msg
        send_resp(conn, code, err_msg)
    end
  end

  put "#{@api_root}/:id/connect" when byte_size(id) > 3 do
    JDLogger.info(@logger, "Connecting #{id} to tracker")
    {status, msg} = @server_impl.connect_torrent_to_tracker(@server_name, id)

    case status do
      :ok ->
        send_resp(conn, 204, "")

      :error ->
        {code, err_msg} = msg
        send_resp(conn, code, err_msg)
    end
  end

  put "#{@api_root}/:id/connect/async" when byte_size(id) > 3 do
    JDLogger.info(@logger, "Connecting #{id} to tracker async")
    _status = @server_impl.connect_torrent_to_tracker_async(@server_name, id)
    JDLogger.debug(@logger, "connect returning success")
    send_resp(conn, 204, "")
  end

  put "#{@api_root}/:id/startTorrent/" when byte_size(id) > 3 do
    JDLogger.info(@logger, "Connecting #{id} to tracker async")
    {status, msg} = @server_impl.start_torrent(@server_name, id)

    case status do
      :error ->
        JDLogger.debug(@logger, "Could not start #{id}, returning error")
        {err_code, msg} = msg
        send_resp(conn, err_code, msg)

      :ok ->
        JDLogger.debug(@logger, "connect returning success")
        send_resp(conn, 204, "")
    end
  end

  put "#{@api_root}/:id/startTorrent/async" when byte_size(id) > 3 do
    JDLogger.info(@logger, "Connecting #{id} to tracker async")
    _status = @server_impl.start_torrent_async(@server_name, id)
    send_resp(conn, 204, "")
  end

  post "#{@api_root}/add/file" do
    conn = Conn.fetch_query_params(conn)
    filename = conn.params["filename"]
    JDLogger.info(@logger, "Received the following filename: #{filename}")
    {status, data} = @server_impl.add_new_torrent(@server_name, filename)

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
    JDLogger.info(@logger, "Received the following torrent id: #{id} to delete")
    {status, data} = @server_impl.delete_torrent_by_id(@server_name, id)

    case status do
      :ok ->
        put_resp_content_type(conn, "application/json")
        send_resp(conn, 200, Poison.encode!(data))

      :error ->
        {code, err_msg} = data
        send_resp(conn, code, err_msg)
    end
  end

  get "#{@api_root}/all" do
    {status, data} = @server_impl.list_current_torrents(@server_name)

    case status do
      :ok ->
        ret =
          Enum.reduce(Map.keys(data), %{}, fn key, acc ->
            val = Map.get(data, key)
            Map.put(acc, key, entry_to_encodable(val))
          end)

        put_resp_content_type(conn, "application/json")
        send_resp(conn, 200, Poison.encode!(ret))

      :error ->
        {code, err_msg} = data
        send_resp(conn, code, err_msg)
    end
  end

  delete "#{@api_root}/remove/all" do
    # TODO: NOT TESTED YET
    {status, data} = @server_impl.delete_all_torrents(@server_name)

    case status do
      :ok ->
        send_resp(conn, 204, "")

      :error ->
        {code, err_msg} = data
        send_resp(conn, code, err_msg)
    end
  end

  match _ do
    send_resp(conn, 404, "oops")
  end

  # this function is created to work with Bento.Metainfo module to encode as json
  defp entry_to_encodable(data_point) do
    {_, new_dp} =
      data_point
      |> Map.get_and_update("metadata", fn metadata ->
        {data_point,
         (fn ->
            {_, new_md} =
              metadata
              |> Map.from_struct()
              |> Map.get_and_update(:info, fn info ->
                {metadata, info |> Map.from_struct() |> Map.delete(:pieces)}
              end)

            new_md
          end).()}
      end)

    new_dp
  end
end
