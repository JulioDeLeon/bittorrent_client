defmodule BittorrentClientTest do
  use ExUnit.Case
  use Plug.Test
  doctest BittorrentClient

  test "the truth" do
    assert 1 + 1 == 2
  end

  # create test for post and put request
  test "compute info hash" do
    file = "priv/debian2.torrent"

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

      expected = "F71E7DEFC014563FC7D8FFE26F759B2518C30F34"
#        "%ea%5d%f1%c9h%ab_%16X%a4%e9%cd.%15%d4%ed%de%ef%ed%1e"
#        |> URI.decode()
#        |> Base.encode16()

      assert hash == expected
      assert URI.encode(hash) == URI.encode(expected)
    end
  end
end

# Pcap info when using Transmission
# 139	32.479680465	192.168.0.3	130.239.18.159	HTTP	424
# GET /announce?
# info_hash=%ea%5d%f1%c9h%ab_%16X%a4%e9%cd.%15%d4%ed%de%ef%ed%1e
# peer_id=-TR2920-vmsfkar3g5jk&port=51413
# uploaded=0
# downloaded=0
# left=1193803776
# numwant=80
# key=675f12e1
# compact=1
# supportcrypto=1
# event=started HTTP/1.1

# Test output
# 1) test compute info hash (BittorrentClientTest)
#    test/bittorrent_client_test.exs:21
#    Assertion with == failed
#    code:  hash == expected
#    left:  "%EA]%F1%C9h%AB_%16X%A4%E9%CD.%15%D4%ED%DE%EF%ED%1E"
#    right: "%ea%5d%f1%c9h%ab_%16X%a4%e9%cd.%15%d4%ed%de%ef%ed%1e"
#    stacktrace:
#      test/bittorrent_client_test.exs:37: (test)
