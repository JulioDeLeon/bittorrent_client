defmodule BittorrentClient.Peer.ConnInfo do
  @derive {Poison.Encoder, except: []}
  defstruct [:ip, :port, :socket, :interval, :timer]

  @type t :: %__MODULE__{
          ip: :inet.port_number(),
          port: :inet.port_number(),
          interval: integer(),
          socket: TCPConn.t(),
          timer: :timer.tref()
        }
end
