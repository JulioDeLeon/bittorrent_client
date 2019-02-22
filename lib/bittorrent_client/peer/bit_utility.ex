defmodule BittorrentClient.Peer.BitUtility do
  @moduledoc """
  Bitutility provides functions which handle the encoding of bitstrings to bitfields.
  """
  require Bitwise
  require Logger
  @byte_size 8
  # 0b10000000 since in bitfield, starting position is leftmost bit
  @byte_starting_pos 128

  @spec set_bit(binary(), integer(), integer()) :: binary()
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
      {_old_val, aft} = String.split_at(temp, 1)
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
      {_old_val, aft} = String.split_at(temp, 1)
      {:ok, before <> <<new_byte>> <> aft}
    end
  end

  def set_bit(<<>>, _val, _pos) do
    {:error, "invalid bitstring"}
  end

  def set_bit(_bitstr, val, _pos) do
    {:error, "invalid value: #{val}"}
  end

  @spec is_set(binary(), integer()) :: {:error, binary()} | {:ok, boolean()}
  def is_set(empty_buff, _pos) when byte_size(empty_buff) == 0 do
    {:error, "empty buffer was given"}
  end

  def is_set(bitstr, pos) do
    if pos >= bit_size(bitstr) || pos < 0 do
      {:error, "invalid position was given"}
    else
      byte_pos = div(pos, 8)
      bit_pos = Bitwise.>>>(@byte_starting_pos, rem(pos, 8))
      <<actual_byte>> = String.at(bitstr, byte_pos)
      {:ok, 0 < Bitwise.&&&(bit_pos, actual_byte)}
    end
  end

  @spec create_full_bitfield(integer(), integer()) :: binary()
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

  @spec create_empty_bitfield(integer(), integer()) :: binary()
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

  @spec parse_bitfield(binary()) :: [integer()]
  def parse_bitfield(empty_bitfield) when byte_size(empty_bitfield) == 0 do
    {:ok, []}
  end

  def parse_bitfield(bitstr) do
    Enum.filter(0..(bit_size(bitstr) - 1), fn i ->
      case is_set(bitstr, i) do
        {:ok, true} ->
          true

        {:error, reason} ->
          Logger.error(reason)
          false

        _ ->
          false
      end
    end)
  end
end
