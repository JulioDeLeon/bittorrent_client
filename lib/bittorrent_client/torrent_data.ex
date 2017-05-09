defmodule BittorrentClient.TorrentData do
  @derive {Poison.Encoder, except: [:pid]}
  defstruct [:id, :pid, :file, :status]
end
