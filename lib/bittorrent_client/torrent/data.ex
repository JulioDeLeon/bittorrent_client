defmodule BittorrentClient.Torrent.Data do
  @moduledoc """
  Torrent data defines struct which will represent relavent torrent worker information to be passed between processes
  """
  @derive {Poison.Encoder, except: [:pid,
                                    :tracker_info,
                                    :info_hash,
                                    :conected_peers
                                   ]}
  defstruct [:id,
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
             :event,
             :ip,
             :numwant,
             :key,
             :trackerid,
             :tracker_info,
             :next_piece_index,
             :pieces,
             :connected_peers
            ]

  @type __MODULE__ :: %__MODULE__{
    id: integer,
    # pid
    file: String.t,
    status: String.t,
    info_hash: String.t,
    peer_id: String.t,
    port: integer,
    uploaded: integer,
    downloaded: integer,
    left: integer,
    compact: boolean,
    no_peer_id: boolean,
    event: String.t,
    ip: String.t,
    numwant: integer,
    key: String.t,
    trackerid: String.t,
    # tracker_info:
    next_piece_index: integer,
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
