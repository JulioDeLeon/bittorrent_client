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
    :expected_piece_length,
    :num_pieces,
    :piece_hashes,
    :piece_length,
    :request_queue,
    :bytes_received,
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
          expected_piece_index: integer(),
          expected_sub_piece_index: integer(),
          expected_piece_length: integer(),
          num_pieces: integer(),
          piece_hashes: list(binary()),
          piece_length: integer(),
          request_queue: [piece_index_request],
          bytes_received: integer(),
          piece_table: map(),
          need_piece: boolean()
        }

  @spec get_known_pieces(__MODULE__.t()) :: list(integer())
  def get_known_pieces(ttinfo), do: Map.keys(ttinfo.piece_table)

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
        ) :: any()
  def populate_single_piece(ttinfo, peer_id, piece_index) do
    {status, _} =
      @torrent_impl.add_new_piece_index(ttinfo.id, peer_id, piece_index)

    add_found_piece_index(status, ttinfo, piece_index)
  end

  @spec populate_multiple_pieces(__MODULE__.t(), peer_id, [piece_index]) ::
          {:ok, __MODULE__.t()} | {:error, reason}
  def populate_multiple_pieces(ttinfo, peer_id, piece_indexes) do
    update_own_table = fn indexes ->
      new_ttinfo =
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
        end)

      {:ok, new_ttinfo}
    end

    case @torrent_impl.add_multi_pieces(ttinfo.id, peer_id, piece_indexes) do
      {:error, msg} ->
        {:error, msg}

      {:ok, indexes} ->
        update_own_table.(indexes)
    end
  end

  @spec get_piece_entry(__MODULE__.t(), piece_index) ::
          {:ok, piece_table_entry} | {:error, reason}
  def get_piece_entry(ttinfo, piece_index) do
    op = fn -> {:ok, Map.get(ttinfo.piece_table, piece_index)} end
    piece_operation(ttinfo, piece_index, op)
  end

  @spec update_piece_entry(__MODULE__.t(), piece_index, piece_table_entry) ::
          {:ok, __MODULE__.t()} | {:error, reason}
  def update_piece_entry(ttinfo, piece_index, entry) do
    op = fn ->
      {:ok,
       %__MODULE__{
         ttinfo
         | piece_table: Map.replace!(ttinfo.piece_table, piece_index, entry)
       }}
    end

    piece_operation(ttinfo, piece_index, op)
  end

  @spec change_piece_progress(__MODULE__.t(), piece_index, piece_progress) ::
          {:ok, __MODULE__.t()} | {:error, reason}
  def change_piece_progress(ttinfo, piece_index, progress) do
    case get_piece_entry(ttinfo, piece_index) do
      {:ok, {_, buff}} ->
        # TODO: if piece is complete empty out the buffer
        update_piece_entry(ttinfo, piece_index, {progress, buff})

      {:error, msg} ->
        {:error, msg}
    end
  end

  @spec mark_piece_done(__MODULE__.t(), piece_index) ::
          {:ok, __MODULE__.t()} | {:error, reason}
  def mark_piece_done(ttinfo, piece_index) do
    handle_valid_piece_buff = fn buff ->
      case @torrent_impl.mark_piece_index_done(ttinfo.id, piece_index, buff) do
        {:ok, _ret} ->
          change_piece_progress(ttinfo, piece_index, :completed)

        {:error, msg} ->
          {:error,
           "#{ttinfo.id} could not mark #{piece_index} as done : #{msg}"}
      end
    end

    case get_piece_entry(ttinfo, piece_index) do
      {:ok, {_, buff}} ->
        handle_valid_piece_buff.(buff)

      {:error, msg} ->
        {:error, msg}
    end
  end

  @spec mark_piece_needed(__MODULE__.t()) :: {:ok, __MODULE__.t()}
  def mark_piece_needed(ttinfo) do
    {:ok, %__MODULE__{ttinfo | need_piece: true}}
  end

  @spec is_piece_needed(__MODULE__.t()) :: boolean()
  def is_piece_needed(ttinfo) do
    ttinfo.need_piece
  end

  @spec add_piece_index_data(
          __MODULE__.t(),
          piece_index,
          integer(),
          integer(),
          binary()
        ) :: {:ok, __MODULE__.t()} | {:error, reason}
  def add_piece_index_data(
        ttinfo,
        piece_index,
        block_offset,
        block_length,
        buff
      ) do
    op = fn ->
      handle_addition_to_piece_buff(
        ttinfo,
        piece_index,
        block_offset,
        block_length,
        buff
      )
    end

    piece_operation(ttinfo, piece_index, op)
  end

  @spec handle_addition_to_piece_buff(
          __MODULE__.t(),
          piece_index,
          integer(),
          integer(),
          binary()
        ) :: {:ok, __MODULE__.t()} | {:error, reason}
  defp handle_addition_to_piece_buff(
         ttinfo,
         piece_index,
         block_offset,
         block_length,
         block
       ) do
    Logger.debug(fn ->
      "ADDITION TO PIECE BUFF : index #{piece_index} block offset #{
        block_offset
      } block length #{block_length}"
    end)

    handle_valid_piece_entry = fn data ->
      case append_piece_buff(data, block, block_offset) do
        {:ok, new_buff} ->
          handle_new_piece_block(
            ttinfo,
            piece_index,
            block_offset,
            block_length,
            new_buff
          )

        {:error, msg} ->
          {:error, msg}
      end
    end

    case get_piece_entry(ttinfo, piece_index) do
      {:ok, {_progress, data}} ->
        handle_valid_piece_entry.(data)

      {:error, msg} ->
        {:error, msg}
    end
  end

  defp handle_new_piece_block(
         ttinfo,
         piece_index,
         block_offset,
         block_length,
         new_buffer
       ) do
    total_received = ttinfo.bytes_received + block_length

    handle_incomplete_piece = fn ->
      total_length = ttinfo.piece_length
      actual_length = byte_size(new_buffer)

      percent = Float.floor(actual_length / total_length * 100, 2)

      Logger.debug(fn ->
        "PIECE PROGRESS : index #{piece_index} : #{percent}%"
      end)

      new_piece_table =
        ttinfo.piece_table
        |> Map.put(piece_index, {:in_progress, new_buffer})

      # TODO: calculate expected length for non byte sizes
      new_ttinfo =
        ttinfo
        |> Map.put(:bytes_received, total_received)
        |> Map.put(:need_piece, false)
        |> Map.put(:expected_piece_index, piece_index)
        |> Map.put(:expected_sub_piece_index, block_offset + block_length)
        |> Map.put(:expected_piece_length, block_length)
        |> Map.put(:piece_table, new_piece_table)

      {:ok, new_ttinfo}
    end

    handle_complete_piece = fn ->
      new_piece_table =
        ttinfo.piece_table
        |> Map.put(piece_index, {:complete, <<>>})

      new_ttinfo =
        ttinfo
        |> Map.put(:piece_table, new_piece_table)
        |> Map.put(:need_piece, true)
        |> Map.put(:bytes_received, 0)

      {:ok, new_ttinfo}
    end

    case check_piece_completed(
           ttinfo,
           piece_index,
           total_received,
           new_buffer
         ) do
      {:ok, :incomplete} ->
        handle_incomplete_piece.()

      {:ok, :complete} ->
        handle_complete_piece.()

      {:error, msg} ->
        {:error, msg}
    end
  end

  defp append_piece_buff(<<>>, block, 0) do
    {:ok, block}
  end

  defp append_piece_buff(buff, block, block_offset) do
    if byte_size(buff) < block_offset do
      {:error, "incorrect block received"}
    else
      {:ok, buff <> block}
    end
  end

  @spec check_piece_completed(__MODULE__.t(), integer(), integer(), binary()) ::
          {:ok, atom()} | {:error, reason}
  defp check_piece_completed(ttinfo, piece_index, total_received, piece_buff) do
    handle_completed_piece = fn ->
      case @torrent_impl.mark_piece_index_done(
             ttinfo.id,
             piece_index,
             piece_buff
           ) do
        {:ok, _} ->
          {:ok, :complete}

        {:error, msg} ->
          Logger.error(
            "#{ttinfo.id} could not mark piece index #{piece_index} as complete : #{
              msg
            }"
          )

          {:error, msg}
      end
    end

    if total_received == ttinfo.piece_length do
      handle_completed_piece.()
    else
      {:ok, :incomplete}
    end
  end

  @spec validate_infohash(__MODULE__.t(), binary()) :: boolean()
  def validate_infohash(ttinfo, pInfohash) do
    pInfohash == ttinfo.infohash
  end

  @spec piece_operation(__MODULE__.t(), piece_index, function()) ::
          any() | {:error, reason}
  defp piece_operation(ttinfo, piece_index, operation) do
    if Map.has_key?(ttinfo.piece_table, piece_index) do
      operation.()
    else
      {:error, "index does not exist in piece table"}
    end
  end

  @spec is_piece_in_progress?(__MODULE__.t()) :: boolean()
  def is_piece_in_progress?(ttinfo) do
    ttinfo.need_piece == false &&
      ttinfo.bytes_recieved < ttinfo.expected_piece_length
  end

  def notify_torrent_of_connection(ttinfo, peer_id, peer_ip, peer_port) do
    @torrent_impl.notify_peer_is_connected(
      ttinfo.id,
      peer_id,
      peer_ip,
      peer_port
    )
  end

  def notify_torrent_of_disconnection(ttinfo, peer_id, peer_ip, peer_port) do
    known_indexes = get_known_pieces(ttinfo)

    @torrent_impl.notify_peer_is_disconnected(
      ttinfo.id,
      peer_id,
      peer_ip,
      peer_port,
      known_indexes
    )
  end
end
