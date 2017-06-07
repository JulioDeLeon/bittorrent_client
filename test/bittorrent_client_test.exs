defmodule BittorrentClientTest do
  use ExUnit.Case
  use Plug.Test
  doctest BittorrentClient

  test "the truth" do
    assert 1 + 1 == 2
  end

  @opts BittorrentClient.Web.init({})
  test "returns Pong" do
    conn = conn(:get, "/ping")
    conn = BittorrentClient.Web.call(conn, @opts)

	  assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body == "pong"
  end

  # create test for post and put request
end

# 934994	374.234654	192.168.0.15	130.239.18.159	HTTP	333	GET /announce?compact=0&downloaded=0&event=started&info_hash=%A2L%157%84%DBE4F%B3%C3%16%04m%5C%F6x%E1%DC%A5&left=660602880&no_peer_id=0&numwant=0&peer_id=-ET0001-&port=6969&uploaded=0 HTTP/1.1
