defmodule PeerTest do
  use ExUnit.Case
  doctest BittorrentClient.Torrent.Peer.GenServerImpl

  setup_all do
    {:ok, sample_arrary: [2, 8, 17], sample_bitstring: <<1::size(32)>>}
  end
end
