defmodule BittorrentClient.Peer.Protocol do
  @moduledoc """
  Peer protocol message decoder and encoder.
  Credit is given to https://github.com/unblevable/T.rex/tree/master/lib/trex/protocol.ex

  https://wiki.theory.org/index.php/BitTorrentSpecification
  """

  require Logger

  # 2^(14)
  @block_len 16_384

  @protocol_string_len 19
  @keep_alive_len 0
  # length of messages with no payload
  @no_payload_len 1
  @have_len 5
  @request_len 13
  @cancel_len 13

  @choke_id 0
  @unchoke_id 1
  @interested_id 2
  @not_interested_id 3
  @have_id 4
  @bitfield_id 5
  @request_id 6
  @piece_id 7
  @cancel_id 8

  # extension messages
  @message_extended 20
  @upload_only_id 3
  @holepunch_id 4
  @dont_have_id 7
  @share_mode_id 8

  @doc """
  Decode a binary of peer protocol messages and return a list of messages and
  any remaining bytes.

  ## Examples
  """
  def decode(binary) do
    decode_type(binary, [])
  end

  defp decode_type(
         <<
           @protocol_string_len,
           "BitTorrent protocol",
           reserved::bytes-size(8),
           info_hash::bytes-size(20),
           peer_id::bytes-size(20),
           rest::bytes
         >>,
         acc
       ) do
    Logger.debug(fn -> "DECODE : HANDSHAKE" end)

    decode_type(rest, [
      %{
        type: :handshake,
        reserved: reserved,
        info_hash: info_hash,
        peer_id: peer_id
      }
      | acc
    ])
  end

  defp decode_type(<<@keep_alive_len::size(32), rest::bytes>>, acc) do
    Logger.debug(fn -> "DECODE : KEEP_ALIVE" end)
    decode_type(rest, [%{type: :keep_alive} | acc])
  end

  defp decode_type(
         <<@no_payload_len::size(32), @choke_id, rest::bytes>>,
         acc
       ) do
    Logger.debug(fn -> "DECODE : CHOKE" end)
    decode_type(rest, [%{type: :choke} | acc])
  end

  defp decode_type(
         <<@no_payload_len::size(32), @unchoke_id, rest::bytes>>,
         acc
       ) do
    Logger.debug(fn -> "DECODE : UNCHOKE" end)
    decode_type(rest, [%{type: :unchoke} | acc])
  end

  defp decode_type(
         <<@no_payload_len::size(32), @interested_id, rest::bytes>>,
         acc
       ) do
    Logger.debug(fn -> "DECODE : INTERESTED" end)
    decode_type(rest, [%{type: :interested} | acc])
  end

  defp decode_type(
         <<@no_payload_len::size(32), @not_interested_id, rest::bytes>>,
         acc
       ) do
    Logger.debug(fn -> "DECODE : NOT_INTERESTED" end)
    decode_type(rest, [%{type: :not_interested} | acc])
  end

  defp decode_type(
         <<@have_len::size(32), @have_id, piece_index::size(32), rest::bytes>>,
         acc
       ) do
    Logger.debug(fn -> "DECODE : HAVE #{piece_index}}" end)
    decode_type(rest, [%{type: :have, piece_index: piece_index} | acc])
  end

  # NOTE: A bitfield of the wrong length is considered an error.
  defp decode_type(<<length::size(32), @bitfield_id, rest::bytes>>, acc)
       when length - 1 == byte_size(rest) do
    Logger.debug(fn -> "DECODE : BITFIELD" end)
    # Subtract the id's length.
    length = length - 1

    if rest == "" do
      Logger.debug(fn -> "Length: #{length}" end)
      Logger.debug(fn -> "Rest: #{rest}" end)
    end

    # if length != byte_size(rest)
    <<bitfield::bytes-size(length), rest::bytes>> = rest

    decode_type(rest, [%{type: :bitfield, bitfield: bitfield} | acc])
  end

  defp decode_type(
         <<
           @request_len::size(32),
           @request_id,
           piece_index::size(32),
           block_offset::size(32),
           block_length::size(32),
           rest::bytes
         >>,
         acc
       ) do
    Logger.debug(fn ->
      "DECODE : REQUEST piece index #{piece_index} block offset #{block_offset} block length #{
        block_length
      }"
    end)

    decode_type(rest, [
      %{
        type: :request,
        piece_index: piece_index,
        block_offset: block_offset,
        block_length: block_length
      }
      | acc
    ])
  end

  defp decode_type(
         <<
           length::size(32),
           @piece_id,
           piece_index::size(32),
           block_offset::size(32),
           n_block::bytes
         >>,
         acc
       ) do
    block_length = calculate_block_length(length)

    Logger.debug(fn ->
      "DECODE : PIECE actual n_b_length #{byte_size(n_block)} cal block length #{
        block_length
      }"
    end)

    block = :binary.part(n_block, 0, block_length)

    rest =
      :binary.part(
        n_block,
        byte_size(n_block),
        block_length - byte_size(n_block)
      )

    Logger.debug(fn ->
      "DECODE : PIECE index #{piece_index} block offset #{block_offset} block length #{
        block_length
      } block #{block}"
    end)

    decode_type(rest, [
      %{
        type: :piece,
        piece_index: piece_index,
        block_length: block_length,
        block_offset: block_offset,
        block: block
      }
      | acc
    ])
  end

  defp decode_type(
         <<
           @cancel_len::size(32),
           @cancel_id,
           piece_index::size(32),
           block_offset::size(32),
           block_length::size(32),
           rest::bytes
         >>,
         acc
       ) do
    Logger.debug(fn ->
      "DECODE : CANCEL piece index #{piece_index} block_offset #{block_offset} block_length #{
        block_length
      }"
    end)

    decode_type(rest, [
      %{
        type: :cancel,
        piece_index: piece_index,
        block_offset: block_offset,
        block_length: block_length
      }
      | acc
    ])
  end

  # Decode Extended Messages
  defp decode_type(
         <<0, 0, 0, 6, @message_extended, @dont_have_id, piece_index::size(32),
           rest::bytes>>,
         acc
       ) do
    Logger.debug(fn ->
      "DECODE : DONT_HAVE MESSAGE piece index #{piece_index}"
    end)

    decode_type(rest, [
      %{
        type: :dont_have,
        piece_index: piece_index
      }
      | acc
    ])
  end

  defp decode_type(
         <<0, 0, 0, 3, @message_extended, @share_mode_id, shared::size(8),
           rest::bytes>>,
         acc
       ) do
    Logger.debug(fn -> "DECODE : SHARE_MODE MESSAGE : #{shared}" end)

    decode_type(rest, [
      %{
        type: :share_mode,
        share_mode: shared
      }
      | acc
    ])
  end

  # Return the list of messages and any remaining bytes.
  defp decode_type(rest, acc) do
    Logger.debug(fn ->
      "DECODE : END OF DECODE REST SIZE #{byte_size(rest)}}"
    end)

    {Enum.reverse(acc), rest}
  end

  @doc """
  Encode a given type and associated data into a peer protocol binary.

  ## Examples
  """
  def encode(:keep_alive) do
    <<@keep_alive_len::size(32)>>
  end

  def encode(:choke) do
    <<@no_payload_len::size(32), @choke_id>>
  end

  def encode(:unchoke) do
    <<@no_payload_len::size(32), @unchoke_id>>
  end

  def encode(:interested) do
    <<@no_payload_len::size(32), @interested_id>>
  end

  def encode(:not_interested) do
    <<@no_payload_len::size(32), @not_interested_id>>
  end

  def encode(:have, piece_index) do
    <<@have_len::size(32), @have_id, piece_index::size(32)>>
  end

  def encode(:bitfield, bitfield) do
    msg = <<@bitfield_id>> <> bitfield
    <<byte_size(msg)::size(32)>> <> msg
  end

  def encode(:dont_have, piece_index) do
    <<0, 0, 0, 6, @message_extended, @dont_have_id, piece_index::size(32)>>
  end

  def encode(:handshake, reserved, info_hash, peer_id) do
    <<
      @protocol_string_len,
      "BitTorrent protocol",
      reserved::bytes-size(8),
      info_hash::bytes-size(20),
      peer_id::bytes-size(20)
    >>
  end

  def encode(:request, piece_index, block_offset, block_len) do
    <<
      @request_len::size(32),
      @request_id,
      piece_index::size(32),
      block_offset::size(32),
      block_len::size(32)
    >>
  end

  def encode(:piece, piece_index, block_offset, piece) do
    msg = <<@piece_id, piece_index::size(32), block_offset::size(32)>> <> piece
    size = 9 + byte_size(piece)
    <<size>> <> msg
  end

  def encode(
        :cancel,
        piece_index,
        block_offset,
        block_length
      ) do
    <<
      @cancel_len::size(32),
      @cancel_id,
      piece_index::size(32),
      block_offset::size(32),
      block_length::size(32)
    >>
  end

  def tcp_buff_to_encoded_msg([x | rst]) do
    <<x>> <> tcp_buff_to_encoded_msg(rst)
  end

  def tcp_buff_to_encoded_msg([]) do
    <<>>
  end

  @piece_length_offset 9
  defp calculate_block_length(length_field),
    do: length_field - @piece_length_offset
end
