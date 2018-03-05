defmodule BittorrentClient.Peer.TorrentTrackingInfo do
  @behaviour :gen_statem
  @derive {Poison.Encoder, except: []}
  defstruct [
    :id,
    :infohash,
    :expected_piece_index,
    :expected_sub_piece_index,
    :piece_length,
    :request_queue,
    :bits_recieved,
    :piece_buffer,
    :piece_table
  ]

  @type piece_index :: integer()
  @type sub_piece_index :: integer()
  @type piece_index_request :: {piece_index, sub_piece_index}
  @type completed :: boolean()
  @type piece_table_entry :: {completed, binary()}
  @type t :: %__MODULE__{
          id: String.t(),
          infohash: binary(),
          expected_piece_index: integer(),
          expected_sub_piece_index: integer(),
          piece_length: integer(),
          request_queue: [piece_index_request],
          piece_buffer: binary(),
          bits_recieved: integer(),
          piece_table: %{piece_index => piece_table_entry}
        }
end
