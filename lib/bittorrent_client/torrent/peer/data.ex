defmodule BittorrentClient.Torrent.Peer.Data do
  @moduledoc """
  Peer data struct to contain information about peer connection
  """
  @derive {Poison.Encoder, except: [:torrent_id,
                                    :socket,
                                    :metainfo,
                                    :timer,
                                    :state
                                   ]}
  defstruct [:torrent_id,
             :peer_id,
             :filename,
             :peer_ip,
             :peer_port,
             :socket,
             :interval,
             :info_hash,
             :handshake_check,
             :metainfo,
             :timer,
             :state,
             :piece_index,
             :sub_piece_index,
             :request_queue, # pieces that you need to serve
             :piece_queue, # pieces the peer has that you want
             :tracker_id,
             :name
            ]
end
