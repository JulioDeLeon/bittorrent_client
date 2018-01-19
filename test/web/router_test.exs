defmodule BittorrentClient.Web.RouterTest do
  use ExUnit.Case
  use Plug.Test
  alias BittorrentClient.Web.Router, as: WebRouter
  doctest WebRouter
  @api_root "/api/v1"
  @server_name "ServerName"
  @server_impl Application.get_env(:bittorrent_client, :server_impl)
  @torrent_impl Application.get_env(:bittorrent_client, :torrent_impl)
  @opts WebRouter.init({})
  @torrent_file "priv/ubuntu.torrent"
  @torrent_file_2 "priv/arch.torrent"
  test "addition of new torrent file" do
    json_body =
      %{"filename" => @torrent_file}
      |> Poison.encode!()

    conn = create_json_request("#{@api_root}/add/file", json_body)
    conn = WebRouter.call(conn, @opts)
    IO.inspect(conn)

    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body != nil

    returned_data =
      conn.resp_body
      |> Poison.decode!()

    #TODO: DELETE THIS LINE IO.inspect(returned_data)
    torrent_id = Map.get(returned_data, "torrent id")

    # TODO: Add server name to application configurations
    # TODO: compare Bento Decoded Data from file to data struct returned
    {status, _data} =
      @server_impl.get_torrent_info_by_id("GenericName", torrent_id)

    assert status = :ok
    torrent_pid = @torrent_impl.whereis(torrent_id)
    assert torrent_pid != :undefined
  end

  defp create_json_request(path, body, content_type \\ "application/json") do
    put_req_header(conn(:post, path, body), "content-type", content_type)
  end
end
