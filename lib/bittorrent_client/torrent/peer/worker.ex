defmodule BittorrentClient.Torrent.Peer.Worker do
  @moduledoc """
  Peer worker to handle peer connections
  https://wiki.theory.org/index.php/BitTorrentSpecification#Peer_wire_protocol_.28TCP.29
  """
  use GenServer
  require Logger
  alias BittorrentClient.Torrent.Peer.Data, :as PeerData

  def start_link({metainfo, torrent_id, peer_id, filename, tracker_id, interval, ip, port}) do
    Logger.info fn -> "Starting peer worker for #{filename}->#{ip}:#{port}" end
    data = %PeerData{}
    # create tcp socket connectiion

    #construct peer_data struct
    GenServer.start_link(
      __MODULE__,
      {data},
      name: {:global, {:btc_peerworker, "#{filename}_#{ip}_#{port}"}})
  end

  def init(peer_data) do
    {:ok, {peer_data}}
  end

  def whereis(id) do
    :global.whereis_name({:btc_peerworker, id})
  end

  def start_peer_handshake(pworker_id) do
    Logger.info fn -> "#{pworker_id} is handshaking" end
    GenServer.call(:global.whereis_name({:btc_peerworker, pworker_id}),
      {:start_handshake})
  end

  def handle_call({:start_handshake}, _from, {peer_info}) do
    """
    The handshake is a required message and must be the first message transmitted by the client. It is (49+len(pstr)) bytes long.

    handshake: <pstrlen><pstr><reserved><info_hash><peer_id>

    pstrlen: string length of <pstr>, as a single raw byte
    pstr: string identifier of the protocol
    reserved: eight (8) reserved bytes. All current implementations use all zeroes. Each bit in these bytes can be used to change the behavior of the protocol. An email from Bram suggests that trailing bits should be used first, so that leading bits may be used to change the meaning of trailing bits.
    info_hash: 20-byte SHA1 hash of the info key in the metainfo file. This is the same info_hash that is transmitted in tracker requests.
    peer_id: 20-byte string used as a unique ID for the client. This is usually the same peer_id that is transmitted in tracker requests (but not always e.g. an anonymity option in Azureus).
    """
  end

end
