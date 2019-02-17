defmodule BittorrentClient.Peer.BitUtility.Test do
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

  test "create empty bitfield based on torrent piece info" do
    piece_length = 32
    pieces = 2
    expected = <<0::size(64)>>
    buff = BitUtility.create_empty_bitfield(pieces, piece_length)
    assert(expected == buff)
  end

  test "create empty buffer" do
    piece_length = 6
    pieces = 3
    expected = <<0::size(24)>>
    buff = BitUtility.create_empty_bitfield(pieces, piece_length)
    assert(expected == buff)
  end

  test "create full bitfield with extra byte" do
    piece_length = 6
    pieces = 3
    expected = <<255, 255, 224>>
    buff = BitUtility.create_full_bitfield(pieces, piece_length)
    assert(buff == expected)
  end

  test "create full bitfield" do
    piece_length = 8
    pieces = 3
    expected = <<255, 255, 255>>
    buff = BitUtility.create_full_bitfield(pieces, piece_length)
    assert(buff == expected)
  end

  test "check if bit is set on certain position" do
    # zero-indexed
    index = 8
    buff = <<0, 128, 0>>
    {:ok, check} = BitUtility.is_set(buff, index)
    assert(check == true)

    index = 2
    {:ok, check} = BitUtility.is_set(buff, index)
    assert(check == false)

    invalid_index = 30
    {check, _} = BitUtility.is_set(buff, invalid_index)
    assert(check == :error)

    buff2 = <<128, 0, 0>>
    index = 0
    {:ok, check} = BitUtility.is_set(buff2, index)
    assert(check == true)

    empty_buff = <<>>
    {check, _} = BitUtility.is_set(empty_buff, index)
    assert(check == :error)

    invalid_index = -1
    {check, _} = BitUtility.is_set(buff2, invalid_index)
    assert(check == :error)
  end
end
