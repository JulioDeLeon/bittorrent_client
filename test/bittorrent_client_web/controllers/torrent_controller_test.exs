defmodule BittorrentClientWeb.TorrentControllerTest do
  use ExUnit.Case, async: false
  use Plug.Test
  alias BittorrentClientWeb.Router, as: WebRouter
  @api_root "/api/v1/torrent"
  @server_name Application.get_env(:bittorrent_client, :server_name)
  @server_impl Application.get_env(:bittorrent_client, :server_impl)
  @torrent_impl Application.get_env(:bittorrent_client, :torrent_impl)
  @torrent_file "priv/ubuntu.torrent"
  @torrent_file_2 "priv/arch.torrent"
  @opts []

  setup do
    file_1_bento_content =
      @torrent_file
      |> File.read!()
      |> Bento.torrent!()

    file_2_bento_content =
      @torrent_file_2
      |> File.read!()
      |> Bento.torrent!()

    on_exit(fn ->
      _ret = @server_impl.delete_all_torrents(@server_name)
    end)

    {:ok, [bento_1: file_1_bento_content, bento_2: file_2_bento_content]}
  end

  describe "torrent/" do
    test "addition of new torrent file on Web Layer" do
      json_body = %{"filename" => @torrent_file}

      conn = create_json_request("#{@api_root}/addFile", json_body)
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

      assert status == :ok
    end

    @opts WebRouter.init([])
    test "status of a nonexistent torrent process should return 400 from Web layer",
         _context do
      fake_id = "superfake"
      conn = conn(:get, "#{@api_root}/#{fake_id}/status")
      conn = WebRouter.call(conn, @opts)
      assert conn.state == :sent
      assert conn.status == 403
      assert conn.resp_body != nil
    end
  end

  test "deletion of a torrent from Web Layer", _context do
    json_body = %{"filename" => @torrent_file}

    conn = create_json_request("#{@api_root}/addFile", json_body)
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

    conn = conn(:get, "#{@api_root}")
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

    conn = conn(:get, "#{@api_root}")
    conn = WebRouter.call(conn, @opts)
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body != nil

    returned_table =
      conn.resp_body
      |> Poison.decode!()

    assert Map.has_key?(returned_table, torrent_id) != true
  end

  test "deletion of all torrents from Web Layer", _context do
    json_body = %{"filename" => @torrent_file}

    conn = create_json_request("#{@api_root}/addFile", json_body)
    conn = WebRouter.call(conn, @opts)
    assert conn.state == :sent
    assert conn.status == 200

    returned_data =
      conn.resp_body
      |> Poison.decode!()

    torrent_id = Map.get(returned_data, "torrent id")

    conn = conn(:get, "#{@api_root}")
    conn = WebRouter.call(conn, @opts)
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body != nil

    returned_table =
      conn.resp_body
      |> Poison.decode!()

    assert Map.has_key?(returned_table, torrent_id) == true

    conn = conn(:delete, "#{@api_root}/removeAll")
    conn = WebRouter.call(conn, @opts)
    assert conn.state == :sent
    assert conn.status == 204
    assert conn.resp_body != nil

    conn = conn(:get, "#{@api_root}")
    conn = WebRouter.call(conn, @opts)
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body != nil

    returned_table =
      conn.resp_body
      |> Poison.decode!()

    assert returned_table == %{}
  end

  test "connect existing torrent to tracker, should return 204 from Web Layer." do
    json_body = %{"filename" => @torrent_file_2}

    conn = create_json_request("#{@api_root}/addFile", json_body)
    conn = WebRouter.call(conn, @opts)
    assert conn.state == :sent
    assert conn.status == 200

    returned_data =
      conn.resp_body
      |> Poison.decode!()

    torrent_id = Map.get(returned_data, "torrent id")

    conn = conn(:put, "#{@api_root}/#{torrent_id}/connect")
    conn = WebRouter.call(conn, @opts)
    assert conn.state == :sent
    assert conn.status == 204
  end

  test "addition of a nonexistent torrent file should return 403 from Web layer",
       _context do
    fake_file = "superfakefile"

    json_body = %{"filename" => fake_file}

    conn = create_json_request("#{@api_root}/addFile", json_body)
    conn = WebRouter.call(conn, @opts)
    assert conn.state == :sent
    assert conn.status == 403
    assert conn.resp_body != nil
  end

  test "deletion of a nonexistent torrent should return 403 from Web ayer",
       _context do
    fake_id = "superfake"
    conn = conn(:delete, "#{@api_root}/#{fake_id}/remove")
    conn = WebRouter.call(conn, @opts)
    assert conn.state == :sent
    assert conn.status == 403
    assert conn.resp_body != nil
  end

  defp create_json_request(path, body, content_type \\ "application/json") do
    put_req_header(conn(:post, path, body), "content-type", content_type)
  end
end
