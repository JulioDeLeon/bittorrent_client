defmodule PeerTest do
  use ExUnit.Case
  doctest BittorrentClient.Peer.GenServerImpl
  alias BittorrentClient.Peer.BitUtility, as: BitUtility

  setup_all do
    {:ok, sample_arrary: [2, 8, 17]}
  end

  test "simple bitwise operating setting <<0,2>>" do
    l = <<0, 2>>
    {status, c} = BitUtility.set_bit(l, 1, 8)
    e = <<0, 130>>
    assert(status == :ok)
    assert(c == e)
  end

  test "simple bitwise operating unsetting <<0,130>>" do
    l = <<0, 130>>
    {status, c} = BitUtility.set_bit(l, 0, 8)
    e = <<0, 2>>
    assert(status == :ok)
    assert(c == e)
  end

  test "simple bitwise operating unsetting <<130>>" do
    l = <<130>>
    {status, c} = BitUtility.set_bit(l, 0, 0)
    e = <<2>>
    assert(status == :ok)
    assert(c == e)
  end

  test "simple bitwise operating unsetting <<0,25,3>>" do
    l = <<0, 25, 3>>
    {status, c} = BitUtility.set_bit(l, 0, 23)
    e = <<0, 25, 2>>
    assert(status == :ok)
    assert(c == e)
  end

  test "empty buffer" do
    l = <<>>
    {status, _reason} = BitUtility.set_bit(l, 1, 44)
    assert(status = :error)
  end

  test "invalid position" do
    l = <<1, 1, 1, 1, 1>>
    {status, _reason} = BitUtility.set_bit(l, 3, 9)
    assert(status = :error)
  end
end
