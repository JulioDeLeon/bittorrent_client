defmodule BittorrentClient.Server do
  @moduledoc """
  Behaviour definition for BittorrentClient's server mechanisms
  """

  @doc """
  Takes a name of a process to return the PID related to the name.
  """
  @callback whereis(name :: String.t) :: pid()

  @doc """
  Returns a GenServer call replay which contains a map of all torrents and their data
  """
  @callback list_current_torrents(serverName :: String.t) :: {atom(), {atom(), map()}, tuple()}

  @doc """
  Attempts to add a new torrent when given a torrent file path. If sucessful, a hash will be returned in GenServer call style. An error message will be returned in GenServer style if unseucessful.
  """
  @callback add_new_torrent(serverName :: String.t, torrentFile :: String.t) :: {atom(), {atom(), String.t}, tuple()}

  @doc """
  Attempts to connect a torrent process to it's relative tracker. Returns a success or failure message in GenServer call style.
  """
  @callback connect_torrent_to_tracker(serverName :: String.t, torrentID :: String.t) :: {atom(), {atom(), String.t}, tuple()}

  @doc """
  Attempts to connect to a torrent process to it's relative tracker asynchronously. does not return feedback in Genserver cast styling.
  """
  @callback connect_torrent_to_tracker_async(serverName :: String.t, torrentID :: String.t) :: (atom())

  @doc """
  Tells torrent process to request peers from the tracker and start requesting data. Will fail if the process has not connect to the tracker yet.
  """
  @callback start_torrent(serverName :: String.t, torrentID :: String.t) :: {atom(), {atom(), String.t}, tuple()}

  @doc """
  Tells torrent process to request peers from the tracker and start request data from peers. This returns In Genserver cast styling.
  """
  @callback start_torrent_async(serverName :: String.t, torrentID :: String.t) :: (atom())

  @doc """
  Retrieves torrent information of preccess. Returns in GenServer all style.
  """
  @callback get_torrent_info_by_id(serverName :: String.t, torrentID :: String.t) :: {atom(), {atom(), any()}, tuple()}

  @doc """
  Deletes torrent process by id, returns in GenServer style.
  """
  @callback delete_torrent_by_id(serverName :: String.t, torrentID :: String.t) :: {atom(), {atom(), String.t}, tuple()}

  @doc """
  Updated the torrent process's data.
  """
  @callback update_torrent_by_id(serverName :: String.t, torrentID :: String.t, data :: struct()) :: {atom(), {atom(), String.t}, tuple()}

  @doc """
  Updated the torrent process's status by id. The status can be :init, :started, :stopped, finished.
  """
  @callback update_torrent_status_by_id(serverName :: String.t, torrentID :: String.t, status :: atom()) :: {atom(), {atom(), String.t}, tuple()}

  @doc """
  Deletes all torrents associated with the server. 
  """
  @callback delete_all_torrents(serverName :: String.t) :: {atom(), {atom(), String.t}, tuple()}
end
