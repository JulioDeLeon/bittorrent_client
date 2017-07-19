defmodule BittorrentClient.Torrent.Peer.State do
  @moduledoc """
  credit to https://github.com/unblevable/T.rex/blob/master/lib/trex/peer.ex
  Mangages peer state, eases TCP connection handling
  """
  @behaviour :gen_fsm
  require Logger
  alias BittorrentClient.Torrent.Peer.Worker, as: PeerWorker

  # TODO: Server states
end
