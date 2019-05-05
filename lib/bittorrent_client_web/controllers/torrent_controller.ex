defmodule BittorrentClientWeb.TorrentController do
  use BittorrentClientWeb, :controller
  require Logger

  @server_impl Application.get_env(:bittorrent_client, :server_impl)
  @server_name Application.get_env(:bittorrent_client, :server_name)

  def ping(conn, _args) do
    send_resp(conn, 200, "pong")
  end

  def status(conn, args) do
    id = Map.get(args, "id")
    Logger.info("Getting status for #{id}")

    case @server_impl.get_torrent_info_by_id(@server_name, id) do
      {:ok, msg} ->
        put_resp_content_type(conn, "application/json")
        data = Map.get(msg, "data")

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

      {:error, {code, msg}} ->
        send_resp(conn, code, msg)
    end
  end

  def info(conn, args) do
    id = Map.get(args, "id")
    Logger.info("Getting info for #{id}")

    case @server_impl.get_torrent_info_by_id(@server_name, id) do
      {:ok, msg} ->
        put_resp_content_type(conn, "application/json")
        send_resp(conn, 200, msg |> entry_to_encodable() |> Poison.encode!())

      {:error, {code, msg}} ->
        send_resp(conn, code, msg)
    end
  end

  def connect(conn, args) do
    id = Map.get(args, "id")
    Logger.info("Connecting #{id} to tracker")

    case @server_impl.connect_torrent_to_tracker(@server_name, id) do
      {:ok, _} ->
        send_resp(conn, 204, "")

      {:error, {code, msg}} ->
        send_resp(conn, code, msg)
    end
  end

  def connect_async(conn, args) do
    id = Map.get(args, "id")
    Logger.info("Connecting #{id} to tracker async")
    @server_impl.connect_torrent_to_tracker_async(@server_name, id)
    send_resp(conn, 204, "")
  end

  def add_file(conn, args) do
    filename = Map.get(args, "filename")
    Logger.info("Received the following filename: #{filename}")

    case @server_impl.add_new_torrent(@server_name, filename) do
      {:ok, data} ->
        put_resp_content_type(conn, "application/json")
        send_resp(conn, 200, Poison.encode!(data))

      {:error, {code, msg}} ->
        send_resp(conn, code, msg)
    end
  end

  def start_torrent(conn, args) do
    id = Map.get(args, "id")
    Logger.info("Starting Torrent #{id}")

    case @server_impl.start_torrent(@server_name, id) do
      {:ok, _} ->
        send_resp(conn, 204, "")

      {:error, {code, msg}} ->
        send_resp(conn, code, msg)
    end
  end

  def start_torrent_async(conn, args) do
    id = Map.get(args, "id")
    Logger.info("Starting Torrent #{id} async")
    @server_impl.start_torrent_async(@server_name, id)
    send_resp(conn, 204, "")
  end

  def delete_torrent(conn, args) do
    id = Map.get(args, "id")
    Logger.info("Received the following torrent id: #{id} to delete")

    case @server_impl.delete_torrent_by_id(@server_name, id) do
      {:ok, data} ->
        put_resp_content_type(conn, "application/json")
        send_resp(conn, 200, Poison.encode!(data))

      {:error, {code, msg}} ->
        send_resp(conn, code, msg)
    end
  end

  def all(conn, _args) do
    case @server_impl.list_current_torrents(@server_name) do
      {:ok, data} ->
        keys = Map.keys(data)

        ret =
          keys
          |> Enum.reduce(%{}, fn key, acc ->
            val = Map.get(data, key)
            Map.put(acc, key, entry_to_encodable(val))
          end)
          |> Poison.encode!()

        put_resp_content_type(conn, "application/json")
        send_resp(conn, 200, ret)

      {:error, {code, msg}} ->
        send_resp(conn, code, msg)
    end
  end

  def remove_all(conn, _args) do
    case @server_impl.delete_all_torrents(@server_name) do
      {:ok, _} ->
        send_resp(conn, 204, "")

      {:error, {code, msg}} ->
        send_resp(conn, code, msg)
    end
  end

  defp entry_to_encodable(data_point) do
    Logger.debug("THIS IS DATA POINT : #{inspect(data_point)}")

    {_, new_metadata} =
      data_point
      |> Map.get("metadata")
      |> Map.from_struct()
      |> Map.get_and_update(:info, fn info ->
        {info, info |> Map.from_struct() |> Map.delete(:pieces)}
      end)

    new_data =
      data_point
      |> Map.get("data")
      |> Map.from_struct()
      |> Map.delete(:pieces)



    data_point
    |> Map.put("metadata", new_metadata)
    |> Map.put("data", new_data)
  end
end
