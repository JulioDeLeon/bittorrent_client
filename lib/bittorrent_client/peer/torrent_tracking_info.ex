defmodule BittorrentClient.Peer.TorrentTrackingInfo do
  @moduledoc """
  TorrentTrackingInfo manages the tracking of torrent download progress
  """
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
          id: String.t() | binary(),
          infohash: binary(),
          expected_piece_index: integer(),
          expected_sub_piece_index: integer(),
          piece_length: integer(),
          request_queue: [piece_index_request],
          piece_buffer: binary(),
          bits_recieved: integer(),
          piece_table: %{piece_index => piece_table_entry}
        }

  @typep tortrackstate :: :ready | :servicing | :err | :completed

  @type callback_mode() :: atom()
  def callback_mode() do
    :state_functions
  end

  @spec init({binary(), binary(), integer()}) :: :gen_statem.init_result(any())
  def init({id, infohash, piece_length}) do
    data = %__MODULE__{
      id: id,
      infohash: infohash,
      piece_length: piece_length,
      expected_piece_index: 0,
      expected_sub_piece_index: 0,
      request_queue: [],
      bits_recieved: 0,
      piece_table: %{},
      piece_buffer: <<>>
    }
    {:ok, :ready, data}
  end

  @spec start(binary(), {binary(), binary(), integer()}) :: :gen_statem.start_ret()
  def start(name, {id, infohash, piece_length}) do
    :gen_statem.start({:global, name}, __MODULE__, {id, infohash, piece_length}, [])
  end

  @spec stop(pid()) :: :ok
  def stop(pid) do
    :gen_statem.stop(pid)
  end
  
  

  def code_change(_Vsn, state, data, _extra) do
    {:ok, state, data}
  end
end