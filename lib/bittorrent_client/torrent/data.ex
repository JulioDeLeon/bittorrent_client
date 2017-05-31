defmodule BittorrentClient.Torrent.Data do
  @moduledoc """
  Torrent data defines struct which will represent relavent torrent worker information to be passed between processes
  """
  @derive {Poison.Encoder, except: [:pid]}
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
             :trackerid
            ]

  def createData(id, pid, file, status, info_hash, peer_id, port, uploaded,
    downloaded, left, compact, no_peer_id, event, ip, numwant, key, trackerid) do
    %__MODULE__{
      id: id,
      pid: pid,
      file: file,
      status: status,
      info_hash: info_hash,
      peer_id: peer_id,
      port: port,
      uploaded: uploaded,
      downloaded: downloaded,
      left: left,
      compact: compact,
      no_peer_id: no_peer_id,
      event: event,
      ip: ip,
      numwant: numwant,
      key: key,
      trackerid: trackerid
    }
  end

  def createInfoHash(info) do
    :crypto.hash(:sha1, "#{inspect info}")
  end
end
