defmodule BittorrentClient.Peer.Supervisor do
  @moduledoc """
  Peer supervisor which is created when a new torrent is created to mange peer connections
  """
  use DynamicSupervisor
  require Logger

  @peer_impl Application.compile_env(:bittorrent_client, :peer_impl)

  def start_link do
    Logger.info("Starting Peer supervisor")
    DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(
        {piece_length, num_pieces, torrent_id, info_hash, filename, interval,
         ip, port}
      ) do
    start_child(
      {piece_length, num_pieces, nil, torrent_id, info_hash, filename, interval,
       ip, port}
    )
  end

  def start_child(
        {piece_length, num_pieces, total_length, torrent_id, info_hash,
         filename, interval, ip, port}
      ) do
    Logger.debug("Starting peer connection for #{torrent_id}")

    child_spec = %{
      id: @peer_impl,
      start:
        {@peer_impl, :start_link,
         [
           {piece_length, num_pieces, total_length, torrent_id, info_hash,
            filename, interval, ip, port}
         ]},
      restart: :temporary
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  def terminate_child(peer_id) do
    pid = @peer_impl.whereis(peer_id)

    case pid do
      :undefined ->
        msg = "invalid peer id was given: #{peer_id}"
        Logger.error(msg)
        {:error, msg}

      _ ->
        ret = DynamicSupervisor.terminate_child(__MODULE__, pid)
        Logger.info("Return of ret #{inspect(ret)}")
        ret
    end
  end
end
