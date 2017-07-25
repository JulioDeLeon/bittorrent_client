defmodule BittorrentClient.Torrent.Peer.Data do
  @moduledoc """
  Peer data struct to contain information about peer connection
  """
  @derive {Poison.Encoder, except: [:torrent_id, :socket]}
  defstruct [:torrent_id,
             :peer_id,
             :filename,
             :tracker_info,
             :ip,
             :port,
             :socket,
             :interval,
             :am_choking,
             :am_interested,
             :peer_choking,
             :peer_interested
            ]
end
