defmodule BittorrentClient.Torrent do
  @moduledoc """
  Api definition of BittorrentClient.Torrent
  """

  @doc """
  whereis returns PID of a named torrent process.
  """
  @callback whereis(torrentID :: String.t()) :: pid()

  @doc """
  start_torrent initiates the communication between peers to start sharing the relative torrent file.
  """
  @callback start_torrent(torrentID :: String.t()) ::
              {atom(), {atom(), String.t(), any()}, tuple()}

  @doc """
  get_torrent_data retrieves the metadata and data of torrent process
  """
  @callback get_torrent_data(torrentID :: String.t()) ::
              {atom(), {atom(), map()}, tuple()}

  @doc """
  connect_to_tracker attempts to connect a torrent process to it's relative tracker to retrieve a peer list.
  """
  @callback connect_to_tracker(torrentID :: String.t()) ::
              {atom(), {atom(), String.t()}, tuple()}

  @doc """
  connect_to_tracker attempts to connect a torrent process to it's relative tracker to retrieve a peer list asynchronously. Return in GenServer cast style. 
  """
  @callback connect_to_tracker_async(torrentID :: String.t()) :: atom()

  @doc """
  """
  @callback get_peers(torrentID :: String.t()) ::
              {atom(), {atom(), struct()}, tuple()}

  @doc """
  """
  @type d_ip :: {integer(), integer(), integer(), integer()}
  @type d_port :: integer()
  @callback start_single_peer(
              torrentID :: String.t(),
              {ip :: d_ip, port :: d_port}
            ) :: {atom(), {atom(), String.t()}, tuple()}

  @doc """
  """
  @callback get_next_piece_index(torrentID :: String.t(), List.t()) ::
              {atom(), tuple(), tuple()}

  @doc """
  """
  @callback mark_piece_index_done(
              torrentID :: String.t(),
              index :: integer(),
              buffer :: bitstring()
            ) :: {atom(), tuple(), tuple()}

  @doc """
  """
  @callback add_new_piece_index(
              torrentID :: String.t(),
              peerID :: String.t(),
              index :: integer
            ) :: {atom(), tuple(), tuple()}

  @doc """
  """
  @callback add_multi_pieces(
              torrentID :: String.t(),
              peerID :: String.t(),
              indexes :: List.t()
            ) :: {atom(), tuple(), tuple()}

  @doc """
  """
  @callback get_completed_piece_list(torrentID :: String.t()) ::
              {atom(), Enum.t(), tuple()}
end
