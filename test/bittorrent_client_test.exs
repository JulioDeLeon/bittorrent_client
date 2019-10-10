defmodule BittorrentClientTest do
  use ExUnit.Case
  use Plug.Test
  doctest BittorrentClient

  test "the truth" do
    assert 1 + 1 == 2
  end

  # create test for post and put request
  test "compute info hash" do
    file = "priv/debian.torrent"

    metadata =
      file
      |> File.read!()
      |> Bento.torrent!()

    {check, info} =
      metadata.info
      |> Map.from_struct()
      |> Map.delete(:md5sum)
      |> Map.delete(:private)
      |> Bento.encode()

    if check == :error do
      assert false
    else
      hash =
        :crypto.hash(:sha, info)
        |> Base.encode16()

      expected = "0F2A3ADFE82E1C92B390CDCAAEC3CDC0DD3EBFD7"

      assert hash == expected
      assert URI.encode(hash) == URI.encode(expected)
    end
  end
end
