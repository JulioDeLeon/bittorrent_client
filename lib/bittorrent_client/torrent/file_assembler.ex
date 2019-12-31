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

    {:atomic, completed_data} =
      :mnesia.transaction(fn ->
        :mnesia.match_object({
          @torrent_cache_name,
          :_,
          src_file,
          :_,
          :complete,
          :_
        })
      end)

    r =
      Enum.sort(completed_data, fn {_, _, _, i1, _, _}, {_, _, _, i2, _, _} ->
        i1 <= i2
      end)

    File.open(output_file, [:write], fn file ->
      Enum.map(r, fn {_, _, _, index, _, buffer} ->
        IO.binwrite(file, buffer)
      end)
    end)

    Logger.info("Assembly of #{output_file} is complete")
  end
end
