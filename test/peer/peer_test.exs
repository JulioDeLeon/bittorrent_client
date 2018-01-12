defmodule PeerTest do
  use ExUnit.Case
  doctest BittorrentClient.Peer.GenServerImpl
  alias BittorrentClient.Peer.BitUtility, as: BitUtility

  setup_all do
    {:ok, sample_arrary: [2, 8, 17]}
  end
end
