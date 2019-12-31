defmodule BittorrentClient.Peer.Protocol.Test do
  use ExUnit.Case
  doctest BittorrentClient.Peer.Protocol
  alias BittorrentClient.Peer.Protocol, as: PeerProtocol
  @piece_id 7

  test "Piece encoding and decoding" do
    block = <<1, 2, 3, 4>>

    data = %{
      type: :piece,
      piece_index: 1,
      block_length: byte_size(block),
      block_offset: 0,
      block: block
    }

    piece_buffer =
      PeerProtocol.encode(
        :piece,
        data.piece_index,
        data.block_length,
        data.block_offset,
        data.block
      )

    c_length = 9 + byte_size(block)

    e_buffer = <<
      c_length::size(32),
      @piece_id,
      data.piece_index::size(32),
      data.block_offset::size(32),
      block::bytes
    >>

    assert piece_buffer == e_buffer

    {[m_data], <<>>} = PeerProtocol.decode(piece_buffer)

    assert data == m_data
  end
end
