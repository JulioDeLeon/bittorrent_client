defmodule BittorrentClient.Torrent.TrackerInfo do
  @moduledoc """
  Tracker info define a wrapper struct for TrackerInfo field of the Bento struct
  so it can be digested by Jason Json Converter.
  """
  @derive {Jason.Encoder, except: [:peers, :peers6]}
  defstruct [:interval, :peers, :peers6]
end
