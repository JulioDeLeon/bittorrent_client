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

  setup_all do
    file_1_bento_content =
      @torrent_file
      |> File.read!()
      |> Bento.torrent!()

    file_2_bento_content =
      @torrent_file_2
      |> File.read!()
      |> Bento.torrent!()

    on_exit fn ->
      IO.puts "on_exit"
      @server_impl.delete_all_torrents(@server_name)
    end

    {:ok, [bento_1: file_1_bento_content, bento_2: file_2_bento_content]}
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

  test "deletion of a torrent from client", context do
    json_body =
      %{"filename" => @torrent_file}
      |> Poison.encode!()

    conn = create_json_request("#{@api_root}/add/file", json_body)
    conn = WebRouter.call(conn, @opts)

    json_body_2 =
      %{"filename" => @torrent_file_2}
      |> Poison.encode!()

    conn = create_json_request("#{@api_root}/add/file", json_body_2)
    conn = WebRouter.call(conn, @opts)

    assert 1 == 1
  end

  defp create_json_request(path, body, content_type \\ "application/json") do
    put_req_header(conn(:post, path, body), "content-type", content_type)
  end
end
