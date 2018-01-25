defmodule BittorrentClient.Peer do
  @moduledoc """
  Handles the bittorrent client's communication with peers
  """

  @doc """
  Returns the pid of a named peer process
  """
  @callback whereis(peer_id :: String) :: pid()
end
