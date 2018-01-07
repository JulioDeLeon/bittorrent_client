defmodule BittorrentClient.Torrent.Peer do
  @moduledoc """
  """

  @doc """
  """
  @callback whereis(peer_id :: String) :: pid()
end
