defmodule PeerTest do
  use ExUnit.Case
  doctest BittorrentClient.Peer.GenServerImpl
  alias BittorrentClient.Peer.BitUtility, as: BitUtility

  setup_all do
    {:ok, sample_arrary: [2, 8, 17]}
  end

  test "simple bitwise oprationg" do
    l = <<0,2>>
    rteff
    e = BitUtility.set_bit()
  end
end
