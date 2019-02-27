defmodule BittorrentClient.Server do
  @moduledoc """
  Behaviour definition for BittorrentClient's server mechanisms
  """
  alias Bento.Metainfo.Torrent, as: TorrentMetainfo
  alias BittorrentClient.Torrent.Data, as: TorrentData
  @type torrent_entry :: %{bitstring() => TorrentMetainfo.t() | TorrentData.t()}
  @type torrent_table :: %{bitstring() => %{bitstring() => torrent_entry}}
  @type http_status :: integer()
  @type reason :: bitstring()
  @type torrent_id :: bitstring()

  @doc """
  Takes a name of a process to return the PID related to the name.
  """
  @callback whereis(name :: String.t()) :: pid()

  @doc """
  Returns a GenServer call replay which contains a map of all torrents and their data
  """
  @callback list_current_torrents(serverName :: String.t()) ::
              {:ok, torrent_table}

  @doc """
  Attempts to add a new torrent when given a torrent file path. If sucessful, a hash will be returned.
  """
  @callback add_new_torrent(serverName :: String.t(), torrentFile :: String.t()) ::
              {:ok, %{bitstring() => torrent_id}}
              | {:error, {http_status, reason}}

  @doc """
  Attempts to connect a torrent process to it's relative tracker.
  """
  @callback connect_torrent_to_tracker(
              serverName :: String.t(),
              torrentID :: String.t()
            ) :: {:ok, reason} | {:error, {http_status, reason}}

  @doc """
  Attempts to connect to a torrent process to it's relative tracker asynchronously.
  """
  @callback connect_torrent_to_tracker_async(
              serverName :: String.t(),
              torrentID :: String.t()
            ) :: :ok

  @doc """
  Tells torrent process to request peers from the tracker and start requesting data. Will fail if the process has not connect to the tracker yet.
  """
  @callback start_torrent(serverName :: String.t(), torrentID :: String.t()) ::
              {:ok, reason} | {:error, {http_status, reason}}

  @doc """
  Tells torrent process to request peers from the tracker and start request data from peers. This returns In Genserver cast styling.
  """
  @callback start_torrent_async(
              serverName :: String.t(),
              torrentID :: String.t()
            ) :: :ok

  @doc """
  Retrieves torrent information of preccess. Returns in GenServer all style.
  """
  @callback get_torrent_info_by_id(
              serverName :: String.t(),
              torrentID :: String.t()
            ) :: {:ok, torrent_entry} | {:error, {http_status, reason}}

  @doc """
  Deletes torrent process by id, returns in GenServer style.
  """
  @callback delete_torrent_by_id(
              serverName :: String.t(),
              torrentID :: String.t()
            ) ::
              {:ok, %{bitstring => torrent_id | torrent_entry}}
              | {:error, {http_status, reason}}

  @doc """
  Updated the torrent process's data.
  """
  @callback update_torrent_by_id(
              serverName :: String.t(),
              torrentID :: String.t(),
              data :: struct()
            ) :: {:ok, torrent_table} | {:error, {http_status, reason}}

  @doc """
  Updated the torrent process's status by id. The status can be :init, :started, :stopped, finished.
  """
  @type torrent_status :: :init | :started | :stopped | :finished
  @callback update_torrent_status_by_id(
              serverName :: String.t(),
              torrentID :: String.t(),
              status :: torrent_status
            ) :: {:ok, torrent_table} | {:error, {http_status, reason}}

  @doc """
  Deletes all torrents associated with the server.
  """
  @callback delete_all_torrents(serverName :: String.t()) ::
              {:ok, torrent_table} | {:error, {http_status, reason}}
end
