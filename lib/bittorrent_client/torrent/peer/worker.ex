defmodule BittorrentClient.Torrent.Peer.Worker do
  @moduledoc """
  Peer worker to handle peer connections
  https://wiki.theory.org/index.php/BitTorrentSpecification#Peer_wire_protocol_.28TCP.29
  """
  use GenServer
  require Logger
  alias BittorrentClient.Torrent.Peer.Data, as: PeerData
  alias BittorrentClient.Torrent.Peer.Protocol, as: PeerProtocol

  def start_link({metainfo, torrent_id, info_hash, filename, tracker_id, interval, ip, port}) do
    name = "#{torrent_id}_#{ip_to_str(ip)}_#{port}"
    peer_data = %PeerData{
      torrent_id: torrent_id,
      peer_id: Application.fetch_env!(:bittorrent_client, :peer_id),
      filename: filename,
      peer_ip: ip,
      peer_port: port,
      interval: interval,
      info_hash: info_hash,
      am_choking: 0,
      am_interested: 0,
      peer_choking: 0,
      peer_interested: 0,
      handshake_check: false,
      metainfo: metainfo,
      timer: nil,
      name: name
    }
    GenServer.start_link(
      __MODULE__,
      {peer_data},
      name: {:global, {:btc_peerworker, name}}
    )
  end

  def init({peer_data})do
    timer = :erlang.start_timer(peer_data.interval, self(), :send_message)
    Logger.info fn -> "Starting peer worker for #{peer_data.name}" end
    sock = connect(peer_data.peer_ip, peer_data.peer_port)
    msg = PeerProtocol.encode(:handshake, <<0::size(64)>>, peer_data.info_hash, peer_data.peer_id)
    send_handshake(sock, msg)
    temp = Map.merge(peer_data, %PeerData{
          handshake_check: true,
          socket: sock,
                     })
    Logger.debug fn -> "After: #{inspect temp}" end
    {:ok, {temp}}
  end

  def whereis(pworker_id) do
    :global.whereis_name({:btc_peerworker, pworker_id})
  end

  @doc  """
  The handshake is a required message and must be the first message transmitted by the client. It is (49+len(pstr)) bytes long.

  handshake: <pstrlen><pstr><reserved><info_hash><peer_id>

  pstrlen: string length of <pstr>, as a single raw byte
  pstr: string identifier of the protocol
  reserved: eight (8) reserved bytes. All current implementations use all zeroes. Each bit in these bytes can be used to change the behavior of the protocol. An email from Bram suggests that trailing bits should be used first, so that leading bits may be used to change the meaning of trailing bits.
  info_hash: 20-byte SHA1 hash of the info key in the metainfo file. This is the same info_hash that is transmitted in tracker requests.
  peer_id: 20-byte string used as a unique ID for the client. This is usually the same peer_id that is transmitted in tracker requests (but not always e.g. an anonymity option in Azureus).
  """

  # Utility
  def ip_to_str({f,s,t,fr}) do
    "#{f}.#{s}.#{t}.#{fr}"
  end

  defp send_handshake(socket, msg) do
    :gen_tcp.send(socket, msg)
  end

  defp connect(ip, port) do
    {:ok, sock} = :gen_tcp.connect(ip, port, [:binary, active: 1], 2_000)
    Logger.debug fn -> "#{ip_to_str(ip)}:#{port} is connected}" end
    sock
  end
end
