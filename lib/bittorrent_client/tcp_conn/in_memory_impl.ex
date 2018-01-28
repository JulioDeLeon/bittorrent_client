defmodule BittorrentClient.TCPConn.InMemoryImpl do
  @moduledoc """
  in_memory implementation of TCPConn behaviour for testing locally
  """
  @behaviour BittorrentClient.TCPConn
  alias BittorrentClient.Logger.Factory, as: LoggerFactory
  alias BittorrentClient.Logger.JDLogger, as: JDLogger
  alias BittorrentClient.TCPConn, as: TCPConn
  @logger LoggerFactory.create_logger(__MODULE__)

  def connect(_ip, _port, _opts) do
    JDLogger.warn(
      @logger,
      "Using #{__MODULE__} implementation of :gen_tcp.connect/3"
    )

    {:ok,
     %TCPConn{
       socket: :mock,
       parent_pid: self()
     }}
  end

  def connect({0, 0, 0, 0}, _port, _opts) do
    JDLogger.warn(
      @logger,
      "Using #{__MODULE__} implementation of :gen_tcp.connect/3"
    )

    {:error, "Bad IP was given"}
  end

  def connect(_ip, _port, _opts, _timeout) do
    JDLogger.warn(
      @logger,
      "Using #{__MODULE__} implementation of :gen_tcp.connect/4"
    )

    {:ok,
     %TCPConn{
       socket: :mock,
       parent_pid: self()
     }}
  end

  def connect({0, 0, 0, 0}, _port, _opts, _timeout) do
    JDLogger.warn(
      @logger,
      "Using #{__MODULE__} implementation of :gen_tcp.connect/4"
    )

    {:error, "Bad IP was given"}
  end

  def accept(tcp_conn) do
    JDLogger.warn(
      @logger,
      "Using #{__MODULE__} implementation of :gen_tcp.accept/1"
    )

    {:ok, %TCPConn{tcp_conn | socket: :mock}}
  end

  def accept(tcp_conn, _timeout) do
    JDLogger.warn(
      @logger,
      "Using #{__MODULE__} implementation of :gen_tcp.accept/2"
    )

    {:ok, %TCPConn{tcp_conn | socket: :mock}}
  end

  def controlling_process(tcp_conn, pid) do
    JDLogger.warn(
      @logger,
      "Using #{__MODULE__} implementation of :gen_tcp.controlling_process/2"
    )

    {:ok, %TCPConn{tcp_conn | parent_pid: pid}}
  end

  def listen(_port, _opts) do
    JDLogger.warn(
      @logger,
      "Using #{__MODULE__} implementation of :gen_tcp.listen/2"
    )

    {:ok, %TCPConn{socket: :mock, parent_pid: self()}}
  end

  def recv(_tcp_conn, len) do
    JDLogger.warn(
      @logger,
      "Using #{__MODULE__} implementation of :gen_tcp.recv/2"
    )

    # have multlple for the various bit protocols?
    {:ok, <<0::size(len)>>}
  end

  def recv(_tcp_conn, len, _timeout) do
    JDLogger.warn(
      @logger,
      "Using #{__MODULE__} implementation of :gen_tcp.recv/3"
    )

    {:ok, <<0::size(len)>>}
  end

  def send(_tcp_conn, _packet) do
    JDLogger.warn(
      @logger,
      "Using #{__MODULE__} implementation of :gen_tcp.send/2"
    )

    :ok
  end

  def close(_tcp_conn) do
    JDLogger.warn(
      @logger,
      "Using #{__MODULE__} implementation of :gen_tcp.close/1"
    )

    :ok
  end

  def shutdown(_tcp_conn, _how) do
    JDLogger.warn(
      @logger,
      "Using #{__MODULE__} implementation of :gen_tcp.shutdown/2"
    )

    :ok
  end
end
