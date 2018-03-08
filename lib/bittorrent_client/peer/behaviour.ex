defmodule BittorrentClient.Peer do
  @moduledoc """
  Handles the bittorrent client's communication with peers
  """

  @doc """
  Returns the pid of a named peer process

  ## Parameters

    - peer_id :: String which represents a peer process' id which is used to be identified by a torrent process

  ## Examples
  ```iex
    iex> Bittorrent.Peer.whereis("AB45EC343324=====")
    #PID<0.21.0>
  ```
  """
  @callback whereis(peer_id :: String) :: pid()
end
