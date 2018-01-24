defmodule BittorrentClient.TCPConn.GenTCPImpl do
  @moduledoc """
  :gen_tcp implementation of TCPConn behaviour
  """
  @behaviour BittorrentClient.TCPConn
  alias BittorrentClient.TCPConn, as: TCPConn

  def connect(ip, port, opts \\ [])do
    {status, socket} = :gen_tcp.connect(ip, port, opts)
    case status do
      :ok ->
        {:ok, %TCPConn{
            socket: socket,
            parent_pid: self()
         }}
    end
  end

  def connect(ip, port, opts, timeout) do
    {status, socket} = :gen_tcp.connect(ip, port, opts, timeout)
    case status do
      :ok ->
        {:ok, %TCPConn{
            socket: socket,
            parent_pid: self()
         }}
    end
  end


end
