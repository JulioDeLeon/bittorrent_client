defmodule BittorrentClient.Web.RouterTest do
  use ExUnit.Case
  use Plug.Test
  alias BittorrentClient.Web.Router, as: WebRouter
  doctest WebRouter
  @api_root "/api/v1"
  @server_name Application.get_env(:bittorrent_client, :server_name)
  @server_impl Application.get_env(:bittorrent_client, :server_impl)
  @torrent_impl Application.get_env(:bittorrent_client, :torrent_impl)
  @opts WebRouter.init({})
  @torrent_file "priv/ubuntu.torrent"
  @torrent_file_2 "priv/arch.torrent"

  setup do
    file_1_bento_content =
      @torrent_file
      |> File.read!()
      |> Bento.torrent!()

    file_2_bento_content =
      @torrent_file_2
      |> File.read!()
      |> Bento.torrent!()

    {:ok, [bento_1: file_1_bento_content, bento_2: file_2_bento_content]}
  end

  setup do
    on_exit(fn ->
      _ret = @server_impl.delete_all_torrents(@server_name)
    end)
  end

  test "addition of new torrent file on Web Layer" do
    json_body =
      %{"filename" => @torrent_file}
      |> Poison.encode!()

    conn = create_json_request("#{@api_root}/add/file", json_body)
    conn = WebRouter.call(conn, @opts)

    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body != nil

    returned_data =
      conn.resp_body
      |> Poison.decode!()

    torrent_id = Map.get(returned_data, "torrent id")
    torrent_pid = @torrent_impl.whereis(torrent_id)
    assert torrent_pid != :undefined

    {status, _data} =
      @server_impl.get_torrent_info_by_id("GenericName", torrent_id)

    assert status = :ok
  end

  test "deletion of a torrent from Web Layer", context do
    json_body =
      %{"filename" => @torrent_file}
      |> Poison.encode!()

    conn = create_json_request("#{@api_root}/add/file", json_body)
    conn = WebRouter.call(conn, @opts)
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body != nil

    returned_data =
      conn.resp_body
      |> Poison.decode!()

    torrent_id = Map.get(returned_data, "torrent id")
    torrent_pid = @torrent_impl.whereis(torrent_id)
    assert torrent_pid != :undefined

    conn = conn(:get, "#{@api_root}/all")
    conn = WebRouter.call(conn, @opts)
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body != nil

    returned_table =
      conn.resp_body
      |> Poison.decode!()

    assert Map.has_key?(returned_table, torrent_id) == true

    conn = conn(:delete, "#{@api_root}/#{torrent_id}/remove")
    conn = WebRouter.call(conn, @opts)
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body != nil

    conn = conn(:get, "#{@api_root}/all")
    conn = WebRouter.call(conn, @opts)
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body != nil

    returned_table =
      conn.resp_body
      |> Poison.decode!()

    assert Map.has_key?(returned_table, torrent_id) != true
  end

  test "deletion of all torrents from Web Layer", context do
    json_body =
      %{"filename" => @torrent_file}
    |> Poison.encode!()

    conn = create_json_request("#{@api_root}/add/file", json_body)
    conn = WebRouter.call(conn, @opts)
    assert conn.state == :sent
    assert conn.status == 200

    returned_data =
      conn.resp_body
      |> Poison.decode!()

    torrent_id = Map.get(returned_data, "torrent id")

    conn = conn(:get, "#{@api_root}/all")
    conn = WebRouter.call(conn, @opts)
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body != nil

    returned_table =
      conn.resp_body
      |> Poison.decode!()

    assert Map.has_key?(returned_table, torrent_id) == true

    conn = conn(:delete, "#{@api_root}/remove/all")
    conn = WebRouter.call(conn, @opts)
    IO.inspect conn.resp_body
    assert conn.state == :sent
    assert conn.status == 204
    assert conn.resp_body != nil

    conn = conn(:get, "#{@api_root}/all")
    conn = WebRouter.call(conn, @opts)
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body != nil

    returned_table =
      conn.resp_body
      |> Poison.decode!()

    assert returned_table == %{}
  end

  test "deletion of a nonexistent torrent should return 400 from Web Layer", context do
    fake_id = "superfake"
    conn = conn(:delete, "#{@api_root}/#{fake_id}/remove")
    conn = WebRouter.call(conn, @opts)
    IO.inspect conn.resp_body
    assert conn.state == :sent
    assert conn.status == 403
    assert conn.resp_body != nil
 end

  test "status of a nonexistent torrent process should return 400 from Web layer", context do
    fake_id = "superfake"
    conn = conn(:get, "#{@api_root}/#{fake_id}/status")
    conn = WebRouter.call(conn, @opts)
    assert conn.state == :sent
    assert conn.status == 403
    assert conn.resp_body != nil
  end

  defp create_json_request(path, body, content_type \\ "application/json") do
    put_req_header(conn(:post, path, body), "content-type", content_type)
  end
end
