defmodule BittorrentClient.Torrent.Data do
  @moduledoc """
  Torrent data defines struct which will represent relavent torrent worker information to be passed between processes
  """
  @derive {Poison.Encoder, except: [:pid]}
  defstruct [:id, :pid, :file, :status, :uploaded, :downloaded, :left]
end
