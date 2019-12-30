defmodule BittorrentClient.Torrent.FileAssembler do
  require Logger
  @torrent_cache_name Application.get_env(:bittorrent_client, :torrent_cache_name)
  @destination_dir Application.get_env(:bittorrent_client, :file_destination)

  def assemble_file({metadata, data}) do
    Logger.debug(fn -> "#{data.id} : assembling #{metadata.info.name}" end)
  end
end
