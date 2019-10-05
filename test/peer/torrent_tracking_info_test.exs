defmodule BittorrentClient.Peer.TorrentTrackingInfo.Test do
  use ExUnit.Case
  doctest BittorrentClient.Peer.TorrentTrackingInfo
  @torrent_impl Application.get_env(:bittorrent_client, :torrent_impl)
  @server_impl Application.get_env(:bittorrent_client, :server_impl)
  @server_name Application.get_env(:bittorrent_client, :server_name)
  @file_name_1 "priv/ubuntu.torrent"
  alias BittorrentClient.Peer.TorrentTrackingInfo, as: TorrentTrackingInfo

  setup_all do
    case @server_impl.add_new_torrent(@server_name, @file_name_1) do
      {:ok, resp} ->
        id = Map.get(resp, "torrent id")
        example_ttinfo = %TorrentTrackingInfo{
          id: id,
          infohash: <<>>,
          expected_piece_index: 0,
          expected_piece_length: 0,
          num_pieces: 0,
          piece_hashes: [],
          piece_length: 0,
          request_queue: [],
          bytes_received: 0,
          piece_table: %{},
          need_piece: true
        }

        # create a dir for byte assembly?
        server_pid = @server_impl.start_link("priv/", @server_name)

        {:ok, [
          torrent_id: id,
          example_ttinfo: example_ttinfo,
          server_pid: server_pid
        ]}
      _ ->
        {:error, "could not add new torrent"}
    end
  end

  setup do
    on_exit(fn ->
      _ret = @server_impl.delete_all_torrents(@server_name)
    end)
  end

  test "Assert get_known_pieces reflects keys in piece table", context do
    ttinfo = %TorrentTrackingInfo{
      id: context.torrent_id,
      piece_table: %{}
    }

    assert length(TorrentTrackingInfo.get_known_pieces(ttinfo)) == 0

    ttinfo = %TorrentTrackingInfo{ ttinfo | piece_table: %{3 => {:found, <<>>}}}

    assert length(TorrentTrackingInfo.get_known_pieces(ttinfo)) == 1
  end

  test "Addition of a new found piece to piece table", context do
    some_index = 4
    ttinfo = context.example_ttinfo
    {status, new_ttinfo} = TorrentTrackingInfo.add_found_piece_index(:ok, ttinfo, some_index)
    assert status == :ok
    known_indexes = TorrentTrackingInfo.get_known_pieces(new_ttinfo)
    assert length(known_indexes) == 1
    assert List.last(known_indexes) == some_index
    ttinfo = new_ttinfo

    another_index = 0
    {status, _new_ttinfo} = TorrentTrackingInfo.add_found_piece_index(:ok, ttinfo, some_index)
    assert status == :error
    {status, new_ttinfo} = TorrentTrackingInfo.add_found_piece_index(:ok, ttinfo, another_index)
    assert status == :ok
    known_indexes = TorrentTrackingInfo.get_known_pieces(new_ttinfo)
    |> Enum.sort()
    assert length(known_indexes) == 2
    assert List.last(known_indexes) == some_index
    assert List.first(known_indexes) == another_index

    ttinfo = new_ttinfo
    another_index_2 = 6
    {status, new_ttinfo} = TorrentTrackingInfo.add_found_piece_index(:error, ttinfo, another_index_2)
    assert status == :ok
    assert ttinfo == new_ttinfo
  end

  test "Populate a single piece reference with torrent process", context do
    some_index = 82
    some_peer_id = 1000 # this is an number from peer data
    ttinfo = context.example_ttinfo
    {status, new_ttinfo} = TorrentTrackingInfo.populate_single_piece(ttinfo, some_peer_id, some_index)
    assert status == :ok
  end
end