defmodule BittorrentClient.Peer.TorrentTrackingInfo do
  @moduledoc """
  TorrentTrackingInfo manages the tracking of torrent download progress
  """
  require Logger
  @torrent_impl Application.get_env(:bittorrent_client, :torrent_impl)
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
    :piece_table,
    :need_piece
  ]

  @type peer_id :: integer()
  @type piece_index :: integer()
  @type sub_piece_index :: integer()
  @type piece_progress :: :found | :completed | :error
  @type piece_index_request :: {piece_index, sub_piece_index}
  @type piece_table_entry :: {piece_progress, binary()}
  @type reason :: binary()
  @type t :: %__MODULE__{
          id: String.t() | binary(),
          infohash: binary(),
          piece_length: integer(),
          request_queue: [piece_index_request],
          piece_buffer: binary(),
          bits_recieved: integer(),
          piece_table: %{piece_index => piece_table_entry}
        }

  @spec add_found_piece_index(atom(), __MODULE__.t(), piece_index) ::
          {:ok, __MODULE__.t()} | {:error, reason}
  def add_found_piece_index(:ok, ttinfo, index) do
    if Map.has_key?(ttinfo.piece_table, index) do
      {:error, "index has already been found"}
    else
      new_piece_table =
        Map.merge(ttinfo.piece_table, %{index => {:found, <<>>}})

      {:ok, %__MODULE__{ttinfo | piece_table: new_piece_table}}
    end
  end

  def add_found_piece_index(:error, ttinfo, _index) do
    {:ok, ttinfo}
  end

  @spec populate_single_piece(
          __MODULE__.t(),
          peer_id,
          piece_index()
        ) :: {:ok, __MODULE__.t()} | {:error | reason}
  def populate_single_piece(ttinfo, peer_id, piece_index) do
    {status, _} =
      @torrent_impl.add_new_piece_index(ttinfo.id, peer_id, piece_index)

    add_found_piece_index(status, ttinfo, piece_index)
  end

  @spec populate_multiple_pieces(__MODULE__.t(), peer_id, [piece_index]) ::
          {:ok, __MODULE__.t()} | {:error, reason}
  def populate_multiple_pieces(ttinfo, peer_id, piece_indexes) do
    case @torrent_impl.add_multi_pieces(ttinfo.id, peer_id, piece_indexes) do
      {:error, msg} ->
        {:error, msg}

      {:ok, indexes} ->
        {:ok,
         Enum.reduce(indexes, ttinfo, fn index, acc ->
           {check, ret} = add_found_piece_index(:ok, acc, index)

           if check == :ok do
             ret
           else
             Logger.error(
               "#{peer_id} could not add #{index} to piece_table : #{ret}"
             )

             acc
           end
         end)}
    end
  end

  @spec update_piece_entry(__MODULE__.t(), piece_index, piece_table_entry) ::
          {:ok, __MODULE__.t()} | {:error, reason}
  def update_piece_entry(ttinfo, piece_index, entry) do
    if Map.has_key?(ttinfo.piece_table, piece_index) do
      {:ok,
       %__MODULE__{
         ttinfo
         | piece_table: Map.replace!(ttinfo.piece_table, piece_index, entry)
       }}
    else
      {:error, "index does not exist in piece table"}
    end
  end

  @spec change_piece_progress(__MODULE__.t(), piece_index, piece_progress) ::
          {:ok, __MODULE__.t()} | {:error, reason}
  def change_piece_progress(ttinfo, piece_index, progress) do
    case get_piece_entry(ttinfo, piece_index) do
      {:ok, {_, buff}} ->
        update_piece_entry(ttinfo, piece_index, {progress, buff})

      {:error, msg} ->
        {:error, msg}
    end
  end

  @spec mark_piece_done(__MODULE__.t(), piece_index) :: {:ok, __MODULE__.t()}
  def mark_piece_done(ttinfo, piece_index) do
    case get_piece_entry(ttinfo, piece_index) do
      {:ok, {_, buff}} ->
        {status, ret} =
          @torrent_impl.mark_piece_index_done(ttinfo.id, piece_index, buff)

        if status == :ok do
          change_piece_progress(ttinfo, piece_index, :completed)
        else
          {:error,
           "#{ttinfo.id} could not mark #{piece_index} as done : #{ret}"}
        end

      {:error, msg} ->
        {:error, msg}
    end
  end

  @spec mark_piece_needed(__MODULE__.t()) :: {:ok, __MODULE__.t()}
  def mark_piece_needed(ttinfo) do
    {:ok, %__MODULE__{ttinfo | need_piece: true}}
  end

  @spec get_piece_entry(__MODULE__.t(), piece_index) ::
          {:ok, piece_table_entry} | {:error, reason}
  def get_piece_entry(ttinfo, piece_index) do
    if Map.has_key?(ttinfo.piece_table, piece_index) do
      {:ok, Map.get(ttinfo.piece_table, piece_index)}
    else
      {:error, "index does not exist in piece table"}
    end
  end

  @spec add_piece_index_data(__MODULE__.t(), piece_index, integer(), integer(), binary()) :: {:ok, __MODULE__.t()} | {:error, reason}
  def add_piece_index_data(ttinfo, piece_index, block_offset, block_length, buff) do
    op = fn ->

    end
    piece_operation(ttinfo, piece_index, op)
  end

  @spec validate_infohash(__MODULE__.t(), binary()) :: boolean()
  def validate_infohash(ttinfo, pInfohash) do
    pInfohash == ttinfo.infohash
  end

  @spec piece_operation(__MODULE__.t(), piece_index, any()):: {:ok, __MODULE__.t()} | {:error, reason}
  defp piece_operation(ttinfo, piece_index, operation) do
    if Map.has_key?(ttinfo.piece_table, piece_index) do
      operation.()
    else
      {:error, "index does not exist in piece table"}
    end
  end
end
