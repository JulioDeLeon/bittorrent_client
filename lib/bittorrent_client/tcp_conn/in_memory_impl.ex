defmodule BittorrentClient.TCPConn.InMemoryImpl do
  @moduledoc """
  in_memory implementation of TCPConn behaviour for testing locally
  """
  @behaviour BittorrentClient.TCPConn
  alias BittorrentClient.TCPConn, as: TCPConn

  def connect(_ip, _port, _opts) do
    {:ok,
     %TCPConn{
       socket: :mock,
       parent_pid: self()
     }}
  end

  def connect({0, 0, 0, 0}, _port, _opts) do
    {:error, "Bad IP was given"}
  end

  def connect(_ip, _port, _opts, _timeout) do
    {:ok,
     %TCPConn{
       socket: :mock,
       parent_pid: self()
     }}
  end

  def connect({0, 0, 0, 0}, _port, _opts, _timeout) do
    {:error, "Bad IP was given"}
  end

  def accept(tcp_conn) do
    {:ok, %TCPConn{tcp_conn | socket: :mock}}
  end

  def accept(tcp_conn, _timeout) do
    {:ok, %TCPConn{tcp_conn | socket: :mock}}
  end

  def controlling_process(tcp_conn, pid) do
    {:ok, %TCPConn{tcp_conn | parent_pid: pid}}
  end

  def listen(_port, _opts) do
    {:ok, %TCPConn{socket: :mock, parent_pid: self()}}
  end

  def recv(_tcp_conn, len) do
    # have multlple for the various bit protocols?
    {:ok, <<0::size(len)>>}
  end

  def recv(_tcp_conn, len, _timeout) do
    {:ok, <<0::size(len)>>}
  end

  def send(_tcp_conn, _packet) do
    :ok
  end

  def close(_tcp_conn) do
    :ok
  end

  def shutdown(_tcp_conn, _how) do
    :ok
  end
end
