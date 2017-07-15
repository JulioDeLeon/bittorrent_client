defmodule BittorrentClient.Torrent.TrackerInfo do
  @moduledoc """
  """
  @derive {Poison.Encoder, except: [:peers, :peers6]}
  defstruct [:interval,
             :peers,
             :peers6
            ]
end
