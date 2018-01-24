defmodule BittorrentClient.TCPConn do
  @moduledoc """
  This module exist to decouple the Peer module from :gen_tcp for local testing, and wrap :gen_tcp for production
  """

  @derive {Poison.Encoder, except: []}
  defstruct [
    :socket,
    :parent_pid
  ]

  @type t :: %__MODULE__{
          # this is to cover both :gen_tcp and the mock module
          socket: any(),
          parent_pid: pid()
        }

  @type reason :: bitstring()

  @doc """
  connect takes an ip and port to return a tcp socket or mock tcp sockcet
  """
  @callback connect(
              ip_param :: :inet.socket_address(),
              port_param :: :inet.port_number(),
              opts :: [:gen_tcp.connect_option()]
            ) :: {:ok, __MODULE__.t()} | {:error, reason}

  @doc """
  connect takes an ip and port to return a tcp socket or mock tcp sockcet within a timeframe
  """
  @callback connect(
              ip_param :: :inet.socket_address(),
              port_param :: :inet.port_number(),
              opts :: [:gen_tcp.connect_option()],
              timeout :: :gen_tcp.timeout()
            ) :: {:ok, __MODULE__.t()} | {:error, reason}

  @doc """
  accepts connection from socket whih is being listened to
  """
  @callback accept(conn :: __MODULE__.t()) ::
              {:ok, __MODULE__.t()} | {:error, reason}

  @doc """
  accepts connection from socket whih is being listened to within a time fram
  """
  @callback accept(conn :: __MODULE__.t(), :gen_tcp.timeout()) ::
              {:ok, __MODULE__.t()} | {:error, reason}

  @doc """
  assigns a new parent process to the tcp conn
  """
  @callback controlling_process(conn :: __MODULE__.t(), pid :: pid()) ::
              {:ok, __MODULE__.t} | {:error, reason}

  @doc """
  setups a conn to listen on a given port
  """
  @callback listen(conn :: __MODULE__.t(), opts :: [:gen_tcp.listen_opts()]) ::
              {:ok, __MODULE__.t()} | {:error, reason}

  @doc """
  receive packets from conn in passive mode, a closed conn will return an error. Optional timeout specifies a timeout in milliseconds. Default is infinity
  """
  @type length :: integer()
  @type packet :: bitstring() | binary() | :gen_tcp.httpPacket()
  @callback recv(__MODULE__.t, len :: length()) :: {:ok, packet} | {:error, reason}
  @callback recv(__MODULE__.t, len :: length(), timeout :: :gen_tcp.timeout()) :: {:ok, packet} | {:error, reason}

  @doc """
  sends bitstring into connection
  """
  @callback send(conn :: __MODULE__.t(), msg :: packet) ::
              :ok | {:error, reason}

  @doc """
  closes the tcp connection
  """
  @callback close(conn :: __MODULE__.t()) :: :ok

  @doc """
  closes in one or two ways. `how` == write closes the conn for writing but still can be read from. `how` == read closes the conn for reading, but still be written to.
  """
  @type how :: :read | :write | :read_write
  @callback shutdown(__MODULE__.t, how :: how) :: :ok | {:error, reason}
end
