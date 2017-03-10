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
