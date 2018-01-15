defmodule BittorrentClient.Torrent.Data do
  @moduledoc """
  Torrent data defines struct which will represent relavent torrent worker information to be passed between processes
  Fields are:
  * `id` - 20-byte SHA1 hash string which uniquely identifies the process.
  * `pid` - Erlang assigned PID for reference (MAY NOT BE NEEDED).
  * `status` - the status of the torrent process, :initial | :started | :finished | :seeding | ???.
  * `info_hash` - 20-byte SHA1 hash to be used in handshake and fact checking steps.
  * `peer_id` - 
  """
  @derive {Poison.Encoder,
           except: [:pid, :tracker_info, :info_hash, :conected_peers]}
  defstruct [
    :id,
    :pid,
    :file,
    :status,
    :info_hash,
    :peer_id,
    :port,
    :uploaded,
    :downloaded,
    :left,
    :compact,
    :no_peer_id,
    :ip,
    :numwant,
    :key,
    :trackerid,
    :tracker_info,
    :pieces,
    :next_piece_index,
    :connected_peers
  ]

  @type __MODULE__ :: %__MODULE__{
          id: integer,
          # pid
          file: String.t(),
          status: String.t(),
          info_hash: String.t(),
          peer_id: String.t(),
          port: integer,
          uploaded: integer,
          downloaded: integer,
          left: integer,
          compact: boolean,
          no_peer_id: boolean,
          ip: String.t(),
          numwant: integer,
          key: String.t(),
          trackerid: String.t(),
          # tracker_info:
          next_piece_index: integer
          # pieces:
          # connected_peers:
        }

  def get_peers(data) do
    data |> Map.get(:tracker_info) |> Map.get(:peers)
  end

  def get_connected_peers(data) do
    data |> Map.get(:connected_peers)
  end
end
