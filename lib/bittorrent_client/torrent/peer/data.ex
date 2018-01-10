defmodule BittorrentClient.Torrent.Peer.Data do
  @moduledoc """
  Peer data struct to contain information about peer connection
  Fields are:
  * `torrent_id` - 20-byte SHA1 hash indentifing the torrent thread.
  * `peer_id` - peer id is a integer which identifies the peer from torrent info.
  * `filename` - filename represents the location of the file releated to the torrent.
  * `peer_ip` - IPv4 address of the peer.
  * `peer_port` - Port which the peer is communicating on.
  * `socket` - ???.
  * `interval` - the time between requests in milliseconds.
  * `info_hash` - 20-byte SHA1 hash to be used during handshake and fact checking.
  * `handshake_check` - boolean to represent if the handshake messages have been exchanged already.
  * `metainfo` - shared metainfo related to torrent obtained from torrent file.
  * `timer` - timer object which will send a process a message at the required intervals.
  * `state` - `:we_choke | :me_choke_it_interests | :me_interest_it_choke | :we_interest`; represent the mode of communication between the process and the peer.
  * `piece_index` - the current piece index the peer worker process is working on.
  * `sub_piece_index` - the subindex of the current piece being worked on.
  * `request_queue` - queue of pieces being requested by peer (MAY NOT BE NEEDED).
  * `piece_table` - map which keeps tracks of desired pieces from peer and it's status. For example, `%{ 5 => :found | :started | :done }`
  * `tracker_id` - string which will represent the bittorrent clients identification.
  * `name` - name which identifies the peer work process which is formated `{torrent_id}_{ip}_{port}`.
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
             :piece_buffer,
             :request_queue, # pieces that you need to serve
             :piece_table,   # pieces the peer has that you want
             :name
            ]
  @type __MODULE__ :: %__MODULE__{
    torrent_id: String.t,
    peer_id: String.t,
    filename: String.t,
    peer_ip: String.t,
    peer_port: integer,
    socket: integer,
    interval: integer,
    info_hash: String.t,
    handshake_check: boolean,
    # metainfo:
    # timer
    # state
    piece_index: integer,
    sub_piece_index: integer,
    # request_queue:
    # piece_queue
    name: String.t
  }
end
