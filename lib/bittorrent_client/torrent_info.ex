defmodule BittorrentClient.TorrentInfo do
  @moduledoc """
  Torrent Info defines data structure for torrent information
  """

  @derive [Poison.Encoder]
  defstruct [:id, :file, :pid, :status]
end
