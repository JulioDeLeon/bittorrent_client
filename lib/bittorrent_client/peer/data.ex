defmodule BittorrentClient.Peer.Data do
  @moduledoc """
  Peer data struct to contain information about peer connection

  ## Peer Connection state 
  The state of the connect between the peer and client is represeneted by 4 atoms as defined: 

  ```elixir
  @type state ::
    :we_choke                 # There is no data being shared between peer and client.
    | :me_choke_it_interest   # The client is not recieving data, but the client is sending data to the peer.
    | :me_interest_it_choke   # The client is recieving data, but the client is not sending data to the peer.
    | :we_interest            # Both the peer and the client are exchanging data.
  ```

  ## Model for Peer Data
  The Peer Data model contains/manages the state of the Peer process.

  ```elixir
  @type t :: %__MODULE__{
      id: String.t(),                                 # Represents peer id for torrent process to identify with
      torrent_tracking_info: TorrentTrackingInfo.t(), # Manages the state of relationship of the peer process with it's torrent process
      filename: String.t(),                           # File that the torrent is related to
      handshake_check: boolean,                       # Check for if the checksum handshake has been made with the peer
      need_piece: boolean,                            # Check to see if a new piece needs to be requested from the peer
      state: state,                                   # Contains the peer connection state
      piece_buffer: binary(),                         # Temporary scratch buffer to contain bytes of the current piece downloaded
      timer: :timer.tref(),                           # Contains reference to a timer which will inform the peer process to send a message
      interval: integer(),                            # Milliseconds of how often messages should be sent
      socket: TCPConn.t(),                            # Contains TCP socket information
      peer_ip: :inet.address(),                       # IP address that peer is listening on
      peer_port: :inet.port(),                        # inet port the peer is listening on
      name: String.t()                                # Name of the peer processs (human readable name for logging)
  }
  ```
  """
  alias BittorrentClient.Peer.TorrentTrackingInfo

  @type state ::
          :we_choke
          | :me_choke_it_interest
          | :me_interest_it_choke
          | :we_interest

  @derive {Poison.Encoder,
           except: [:torrent_id, :socket, :metainfo, :timer, :state]}
  defstruct [
    :id,
    :torrent_tracking_info,
    :handshake_check,
    :need_piece,
    :filename,
    :state,
    :piece_buffer,
    :timer,
    :interval,
    :socket,
    :peer_ip,
    :peer_port,
    :name
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          torrent_tracking_info: TorrentTrackingInfo.t(),
          filename: String.t(),
          handshake_check: boolean,
          need_piece: boolean,
          state: state,
          piece_buffer: binary(),
          timer: :timer.tref(),
          interval: integer(),
          socket: TCPConn.t(),
          peer_ip: :inet.address(),
          peer_port: :inet.port(),
          name: String.t()
        }
end
