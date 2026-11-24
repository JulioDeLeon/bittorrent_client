defmodule BittorrentClient.Torrent.FileAssembler do
  @moduledoc """
  FileAssembler examines an mnesia cache for the given torrent data to assemble
  single-file or multi-file torrents.
  """
  require Logger

  @torrent_cache_name Application.compile_env(
                        :bittorrent_client,
                        :torrent_cache_name
                      )
  @destination_dir Application.compile_env(
                     :bittorrent_client,
                     :file_destination
                   )

  def assemble_file({metadata, data}, destination_dir \\ @destination_dir) do
    name = Map.get(metadata.info, :name) || "download"
    src_file = data.file
    files = Map.get(metadata.info, :files)

    if is_list(files) and files != [] do
      base_dir = Path.join(destination_dir, name)
      assemble_multi_file(base_dir, files, src_file, data.num_pieces)
      Logger.info("Assembly of multi-file torrent #{base_dir} is complete")
    else
      output_file = Path.join(destination_dir, name)
      assemble_single_file(output_file, src_file, data.num_pieces)
      Logger.info("Assembly of #{output_file} is complete")
    end
  end

  defp assemble_single_file(output_file, _src_file, num_pieces)
       when num_pieces <= 0 do
    File.mkdir_p!(Path.dirname(output_file))
    File.touch!(output_file)
  end

  defp assemble_single_file(output_file, src_file, num_pieces) do
    File.mkdir_p!(Path.dirname(output_file))

    File.open!(output_file, [:write], fn file_h ->
      for i <- 0..(num_pieces - 1) do
        case pop_piece_buffer(src_file, i) do
          {:ok, buffer} -> IO.binwrite(file_h, buffer)
          :error -> :ok
        end
      end
    end)
  end

  defp assemble_multi_file(base_dir, files, src_file, num_pieces) do
    file_entries =
      Enum.map(files, fn f ->
        rel_path = f |> Map.get(:path) |> Path.join()
        full_path = Path.join(base_dir, rel_path)
        File.mkdir_p!(Path.dirname(full_path))
        File.touch!(full_path)
        {full_path, Map.get(f, :length) || 0}
      end)

    if num_pieces > 0 do
      piece_stream =
        Stream.map(0..(num_pieces - 1), fn i ->
          case pop_piece_buffer(src_file, i) do
            {:ok, buffer} -> buffer
            :error -> <<>>
          end
        end)

      {remaining_files, current_handle, _} =
        Enum.reduce(piece_stream, {file_entries, nil, 0}, fn buffer, state ->
          write_across_files(buffer, state)
        end)

      if current_handle != nil, do: File.close(current_handle)

      Enum.each(remaining_files, fn {_path, _len} -> :ok end)
    end
  end

  defp write_across_files(<<>>, state), do: state

  defp write_across_files(buffer, {[], nil, 0}) do
    {[], nil, byte_size(buffer)}
  end

  defp write_across_files(buffer, {[{path, len} | rest], nil, 0}) do
    if len == 0 do
      write_across_files(buffer, {rest, nil, 0})
    else
      handle = File.open!(path, [:write, :binary])
      write_across_files(buffer, {rest, handle, len})
    end
  end

  defp write_across_files(buffer, {rest, handle, remaining}) do
    buf_size = byte_size(buffer)

    if buf_size <= remaining do
      IO.binwrite(handle, buffer)
      new_remaining = remaining - buf_size

      if new_remaining == 0 do
        File.close(handle)
        {rest, nil, 0}
      else
        {rest, handle, new_remaining}
      end
    else
      <<chunk::binary-size(remaining), leftover::binary>> = buffer
      IO.binwrite(handle, chunk)
      File.close(handle)
      write_across_files(leftover, {rest, nil, 0})
    end
  end

  defp pop_piece_buffer(src_file, index) do
    transaction_result =
      :mnesia.transaction(fn ->
        case :mnesia.match_object({
               @torrent_cache_name,
               :_,
               src_file,
               index,
               :complete,
               :_
             }) do
          [{p0, p1, p2, p3, p4, buffer} | _] ->
            :mnesia.delete_object({p0, p1, p2, p3, p4, buffer})
            {:ok, buffer}

          [] ->
            :missing
        end
      end)

    case transaction_result do
      {:atomic, {:ok, buffer}} ->
        {:ok, buffer}

      {:atomic, :missing} ->
        Logger.warn(
          "Piece #{index} for #{src_file} was not found in cache during assembly"
        )

        :error

      {:aborted, reason} ->
        Logger.error(
          "Failed to read piece #{index} from cache: #{inspect(reason)}"
        )

        :error
    end
  end
end
