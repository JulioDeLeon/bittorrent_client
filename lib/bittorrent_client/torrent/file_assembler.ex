defmodule BittorrentClient.Torrent.FileAssembler do
  require Logger

  @torrent_cache_name Application.get_env(
                        :bittorrent_client,
                        :torrent_cache_name
                      )
  @destination_dir Application.get_env(:bittorrent_client, :file_destination)

  def assemble_file({metadata, data}) do
    output_file = "#{@destination_dir}#{metadata.info.name}"
    src_file = data.file
    File.touch!(output_file)

    perform_assembly = fn file_h, i ->
      {:atomic, _} =
        :mnesia.transaction(fn ->
          [{p0, p1, p2, p3, p4, buffer}] = :mnesia.match_object({
            @torrent_cache_name,
            :_,
            src_file,
            i,
            :complete,
            :_
          })

          IO.binwrite(file_h, buffer)

          :mnesia.delete_object({p0, p1, p2, p3, p4, buffer})
        end)
      :ok
    end

    File.open(output_file, [:write], fn file_h ->
      for i <- (0..data.num_pieces-1) do
        perform_assembly.(file_h, i)
      end
    end)

    Logger.info("Assembly of #{output_file} is complete")
  end
end
