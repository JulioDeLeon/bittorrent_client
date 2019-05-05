defmodule BittorrentClient.Torrent do
  @moduledoc """
  Api definition of BittorrentClient.Torrent
  """
  alias Bento.Metainfo.Torrent, as: TorrentMetainfo
  alias Bittorrent.Peer.Data, as: PeerData
  alias Bittorrent.Torrent.Data, as: TorrentData

  @type torrentID :: String.t()
  @type peerID :: String.t()
  @type peerIP :: {integer(), integer(), integer(), integer()}
  @type peerPort :: integer()

  @doc """
  whereis returns PID of a named torrent process.
  """
  @callback whereis(torrentID) :: pid()

  @doc """
  start_torrent initiates the communication between peers to start sharing the relative torrent file.
  """
  @callback start_torrent(torrentID) ::
              {atom(), {atom(), String.t(), any()}, tuple()}

  @doc """
  get_torrent_data retrieves the metadata and data of torrent process
  """
  @type reason :: bitstring()
  @callback get_torrent_data(torrentID) :: {:ok, TorrentData.t()}

  @doc """
  connect_to_tracker attempts to connect a torrent process to it's relative tracker to retrieve a peer list.
  """
  @callback connect_to_tracker(torrentID) ::
              {:ok, {TorrentMetainfo.t(), TorrentData.t()}} | {:error, reason}
  @doc """
  connect_to_tracker attempts to connect a torrent process to it's relative tracker to retrieve a peer list asynchronously. Return in GenServer cast style.
  """
  @callback connect_to_tracker_async(torrentID) :: any()

  @doc """
  Gets the peers related to a torrent process
  """
  @callback get_peers(torrentID) ::
              {:ok, [{:inet.socket_address(), :inet.port_number()}]}

  @doc """
  Starts sharing the torrent from a single peer from the peer list
  """
  @callback start_single_peer(
              torrentID,
              {ip :: :inet.socket_address(), port :: :inet.port_number()}
            ) :: {:ok, PeerData.t()} | {:error, reason}

  @doc """
  Returns the next piece index for a peer to work on, Will return error if no work is available.
  """
  @callback get_next_piece_index(torrentID, [integer()]) ::
              {:ok, integer()} | {:error, reason}

  @doc """
  Marks a piece index on the torrent's piece table as done (meaing it can be shared)
  """
  @callback mark_piece_index_done(
              torrentID,
              index :: integer(),
              buffer :: bitstring()
            ) :: {:ok, integer()} | {:error, reason}

  @doc """
  Adds a new piece to the piece table, marking the piece as available to be worked on
  """
  @callback add_new_piece_index(
              torrentID,
              peerID,
              index :: integer
            ) :: {:ok, reason} | {:error, reason}

  @doc """
  Similar to add_new_piece_index, will add a list of indexes to a table, returning a list of pieces that were not added.
  """
  @callback add_multi_pieces(
              torrentID,
              peerID,
              indexes :: [integer()]
            ) :: {:ok, [integer()]} | {:error, reason}

  @doc """
  Returns a list of completed pieces by index
  """
  @callback get_completed_piece_list(torrentID) ::
              {:ok, [integer()]} | {:error, reason}

  @doc """
  Sets the number of concurrent peers for the torrent process
  """
  @callback set_number_peers(torrentID, num_wanted :: integer()) ::
              :ok | {:error, reason}

  @doc """
  Updates the connected peer list with given peer id
  """
  @callback notify_peer_is_connected(torrentID, peerID, peerIP, peerPort) ::
              :ok | {:error, reason}

  @doc """
  Udpates connected peer list to remove the given peer id from list, decrements known indexes
  """
  @callback notify_peer_is_disconnected(
              torrentID,
              peerID,
              peerIP,
              peerPort,
              list(integer())
            ) ::
              :ok | {:error, reason}
end
