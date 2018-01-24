defmodule BittorrentClient.TCPConn.InMemoryImpl do
  @moduledoc """
  in_memory implementation of TCPConn behaviour for testing locally
  """
  @behaviour BittorrentClient.TCPConn
  alias BittorrentClient.TCPConn, as: TCPConn

  def connect(ip, port, opts \\ []) do
    {status, ret} = :gen_tcp.connect(ip, port, opts)

    case status do
      :ok ->
        {:ok,
         %TCPConn{
           socket: ret,
           parent_pid: self()
         }}

      _ ->
        {status, ret}
    end
  end

  def connect(ip, port, opts, timeout) do
    {status, socket} = :gen_tcp.connect(ip, port, opts, timeout)

    case status do
      :ok ->
        {:ok,
         %TCPConn{
           socket: socket,
           parent_pid: self()
         }}
    end
  end

  def accept(tcp_conn) do
    {status, ret} = :gen_tcp.accept(tcp_conn.socket)

    case status do
      :ok ->
        {:ok, %TCPConn{tcp_conn | socket: ret}}

      _ ->
        {status, ret}
    end
  end

  def accept(tcp_conn, timeout) do
    {status, ret} = :gen_tcp.accept(tcp_conn.socket, timeout)

    case status do
      :ok ->
        {:ok, %TCPConn{tcp_conn | socket: ret}}

      _ ->
        {status, ret}
    end
  end

  def controlling_process(tcp_conn, pid) do
    ret = :gen_tcp.controlling_process(tcp_conn.socket, pid)

    case ret do
      :ok ->
        {:ok, %TCPConn{tcp_conn | parent_pid: pid}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def listen(port, opts) do
    {status, ret} = :gen_tcp.listen(port, opts)

    case status do
      :ok ->
        {:ok, %TCPConn{socket: ret, parent_pid: self()}}

      _ ->
        {:error, ret}
    end
  end

  def recv(tcp_conn, len) do
    :gen_tcp.recv(tcp_conn.socket, len)
  end

  def recv(tcp_conn, len, timeout) do
    :gen_tcp.recv(tcp_conn.socket, len, timeout)
  end

  def send(tcp_conn, packet) do
    :gen_tcp.send(tcp_conn.socket, packet)
  end

  def close(tcp_conn) do
    :gen_tcp.close(tcp_conn.socket)
  end

  def shutdown(tcp_conn, how) do
    :gen_tcp.close(tcp_conn.socket)
  end
end
