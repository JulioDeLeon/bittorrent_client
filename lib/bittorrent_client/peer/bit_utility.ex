defmodule BittorrentClient.Peer.BitUtility do
  require Bitwise
  require Logger
  @byte_size 8

  def set_bit(bitstr, 1, pos) do
    size = byte_size(bitstr)

    if pos < 0 || div(pos, @byte_size) - 1 > size do
      {:error, "invalid position was given"}
    else
      bitstring_index = div(pos, @byte_size)
      bit_index = @byte_size - rem(pos, @byte_size)
      <<desired_byte_val>> = String.at(bitstr, bitstring_index)
      new_byte = Bitwise.|||(desired_byte_val, Bitwise.<<<(1, bit_index - 1))
      {before, temp} = String.split_at(bitstr, bitstring_index)
      {_oldVal, aft} = String.split_at(temp, 1)
      {:ok, before <> <<new_byte>> <> aft}
    end
  end

  def set_bit(bitstr, 0, pos) do
    size = byte_size(bitstr)

    if pos < 0 || div(pos, @byte_size) - 1 > size do
      {:error, "invalid position was given"}
    else
      bitstring_index = div(pos, @byte_size)
      bit_index = @byte_size - rem(pos, @byte_size)
      <<desired_byte_val>> = String.at(bitstr, bitstring_index)

      new_byte =
        Bitwise.&&&(desired_byte_val, 255 - Bitwise.<<<(1, bit_index - 1))

      {before, temp} = String.split_at(bitstr, bitstring_index)
      {_oldVal, aft} = String.split_at(temp, 1)
      {:ok, before <> <<new_byte>> <> aft}
    end
  end

  def set_bit(<<>>, _val, _pos) do
    {:error, "invalid bitstring"}
  end

  def set_bit(_bitstr, val, _pos) do
    {:error, "invalid value: #{val}"}
  end

  def create_full_bitfield(num_pieces, piece_length) do
    max_bits = num_pieces * piece_length
    bytes_needed = div(max_bits, @byte_size)
    bits_needed = bytes_needed * @byte_size
    excess_bits = rem(max_bits, @byte_size)
    max_binary_value = Bitwise.<<<(1, bytes_needed * @byte_size + 1) - 1
    initial_buffer = <<max_binary_value::size(bits_needed)>>

    extra_byte =
      if excess_bits == 0 do
        <<>>
      else
        excess_indexes = for x <- 0..excess_bits, do: x

        Enum.reduce(excess_indexes, <<0::size(@byte_size)>>, fn index, buff ->
          {status, new_buff} = set_bit(buff, 1, index)

          case status do
            :ok -> new_buff
            _ -> buff
          end
        end)
      end

    initial_buffer <> extra_byte
  end

  def create_empty_bitfield(num_pieces, piece_length) do
    max_bits = num_pieces * piece_length

    extra_byte =
      if rem(max_bits, @byte_size) == 0 do
        0
      else
        1
      end

    bytes_needed = div(max_bits, @byte_size) + extra_byte
    bits_needed = bytes_needed * @byte_size
    <<0::size(bits_needed)>>
  end
end
