defmodule BittorrentClient.Torrent.Data do
  @derive {Poison.Encoder, except: [:pid]}
  defstruct [:id, :pid, :file, :status]
end
