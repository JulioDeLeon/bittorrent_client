defmodule BittorrentClient.Peer.BitUtility  do
  require Bitwise
  @byte_size 8

  def set_bit(bitstr, 1, pos) when byte_size(bitstr) > 0 do
    bitstring_index = div(pos, @byte_size)
    bit_index = @byte_size - (rem(pos, @byte_size) - 1)
    <<desired_byte_val>> = String.at(bitstr, bitstring_index)
    new_byte = <<Bitwise.|||(desired_byte_val, Bitwise.<<<(1, bit_index))>>
    {before, temp} = String.split_at(bitstr, bitstring_index)
    {_oldVal, aft} = String.split_at(temp, 1)
    {:ok, before <> <<new_byte>> <> aft}
  end

  def set_bit(bitstr, 0, pos) when byte_size(bitstr) > 0 do
    bitstring_index = div(pos, @byte_size)
    bit_index = @byte_size - (rem(pos, @byte_size) - 1)
    <<desired_byte_val>> = String.at(bitstr, bitstring_index)
    new_byte = <<Bitwise.&&&(desired_byte_val, Bitwise.<<<(0, bit_index))>>
    {before, temp} = String.split_at(bitstr, bitstring_index)
    {_oldVal, aft} = String.split_at(temp, 1)
    {:ok, before <> <<new_byte>> <> aft}
  end

  def set_bit(<<>>, _val, _pos) do
    {:error, "invalid bitstring"}
  end

  def set_bit(_bitstr, val, _pos) do
    {:error, "invalid valuew"}
  end
end
