defmodule BittorrentClient.Peer.TorrentTrackingInfo.Test do
  use ExUnit.Case, async: true
  doctest BittorrentClient.Peer.TorrentTrackingInfo
  @server_impl Application.get_env(:bittorrent_client, :server_impl)
  @server_name Application.get_env(:bittorrent_client, :server_name)
  @file_name_1 "priv/ubuntu_2.torrent"
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
          piece_length: 0,
          request_queue: [],
          bytes_received: 0,
          piece_table: %{},
          need_piece: true
        }

        # create a dir for byte assembly?

        {:ok,
         [
           torrent_id: id,
           example_ttinfo: example_ttinfo
         ]}

      _ ->
        {:error, "could not add new torrent"}
    end
  end

  setup do
    _ret = @server_impl.delete_all_torrents(@server_name)

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

    ttinfo = %TorrentTrackingInfo{ttinfo | piece_table: %{3 => {:found, <<>>}}}

    assert length(TorrentTrackingInfo.get_known_pieces(ttinfo)) == 1
  end

  test "Addition of a new found piece to piece table", context do
    some_index = 4
    ttinfo = context.example_ttinfo

    {status, new_ttinfo} =
      TorrentTrackingInfo.add_found_piece_index(:ok, ttinfo, some_index)

    assert status == :ok
    known_indexes = TorrentTrackingInfo.get_known_pieces(new_ttinfo)
    assert length(known_indexes) == 1
    assert List.last(known_indexes) == some_index
    ttinfo = new_ttinfo

    another_index = 0

    {status, _new_ttinfo} =
      TorrentTrackingInfo.add_found_piece_index(:ok, ttinfo, some_index)

    assert status == :error

    {status, new_ttinfo} =
      TorrentTrackingInfo.add_found_piece_index(:ok, ttinfo, another_index)

    assert status == :ok

    known_indexes =
      TorrentTrackingInfo.get_known_pieces(new_ttinfo)
      |> Enum.sort()

    assert length(known_indexes) == 2
    assert List.last(known_indexes) == some_index
    assert List.first(known_indexes) == another_index

    ttinfo = new_ttinfo
    another_index_2 = 6

    {status, new_ttinfo} =
      TorrentTrackingInfo.add_found_piece_index(:error, ttinfo, another_index_2)

    assert status == :ok
    assert ttinfo == new_ttinfo
  end

  test "Populating piece reference on dead process", context do
    some_index = 82
    # this is an number from peer data
    some_peer_id = 1000
    ttinfo = %TorrentTrackingInfo{context.example_ttinfo | id: "fake"}

    {status, _new_ttinfo} =
      TorrentTrackingInfo.populate_single_piece(
        ttinfo,
        some_peer_id,
        some_index
      )

    assert status == :error
  end

  test "Populate a single piece reference with torrent process", context do
    some_index = 82
    some_peer_id = 93298
    ttinfo = setup_torrent(context)

    {status, new_ttinfo} =
      TorrentTrackingInfo.populate_single_piece(
        ttinfo,
        some_peer_id,
        some_index
      )

    assert status == :ok
    piece_table = Map.get(new_ttinfo, :piece_table)

    assert Map.has_key?(piece_table, some_index) == true
    assert Map.get(piece_table, some_index) == {:found, <<>>}
  end

  test "Populate multiple piece references with torrent process", context do
    some_indexes = [99, 22, 828]
    some_peer_id = 93939
    ttinfo = setup_torrent(context)

    {status, new_ttinfo} =
      TorrentTrackingInfo.populate_multiple_pieces(
        ttinfo,
        some_peer_id,
        some_indexes
      )

    assert status == :ok
    piece_table = Map.get(new_ttinfo, :piece_table)

    _ret =
      Enum.map(some_indexes, fn index ->
        assert Map.has_key?(piece_table, index) == true
        assert Map.get(piece_table, index) == {:found, <<>>}
      end)
  end

  test "Getting piece index info", context do
    some_index = 3
    some_peer_id = 322_343

    ttinfo = %TorrentTrackingInfo{
      id: context.example_ttinfo.id
    }

    {status, _ret} = TorrentTrackingInfo.get_piece_entry(ttinfo, some_index)
    assert status == :error

    ebuff = <<3, 3, 3, 3>>

    {status, _ret} =
      TorrentTrackingInfo.update_piece_entry(
        ttinfo,
        some_index,
        {:working, ebuff}
      )

    assert status == :error

    ttinfo = setup_torrent(context)

    {:ok, new_ttinfo} =
      TorrentTrackingInfo.populate_single_piece(
        ttinfo,
        some_peer_id,
        some_index
      )

    lst = TorrentTrackingInfo.get_known_pieces(new_ttinfo)
    assert length(lst) == 1

    {:ok, value} = TorrentTrackingInfo.get_piece_entry(new_ttinfo, some_index)
    assert value == {:found, <<>>}

    {status, new_ttinfo} =
      TorrentTrackingInfo.update_piece_entry(
        new_ttinfo,
        some_index,
        {:working, ebuff}
      )

    assert status == :ok
    {:ok, value} = TorrentTrackingInfo.get_piece_entry(new_ttinfo, some_index)
    assert value == {:working, ebuff}
  end

  test "Changing Piece Progress", context do
    ttinfo = %TorrentTrackingInfo{
      id: context.example_ttinfo.id
    }

    eprogress = :working
    some_index = 4
    some_peer_id = 324_890

    {status, _ret} =
      TorrentTrackingInfo.change_piece_progress(ttinfo, some_index, eprogress)

    assert status == :error
    ttinfo = setup_torrent(context)

    {:ok, new_ttinfo} =
      TorrentTrackingInfo.populate_single_piece(
        ttinfo,
        some_peer_id,
        some_index
      )

    {:ok, new_ttinfo} =
      TorrentTrackingInfo.change_piece_progress(
        new_ttinfo,
        some_index,
        eprogress
      )

    {status, {aprogress, _buff}} =
      TorrentTrackingInfo.get_piece_entry(new_ttinfo, some_index)

    assert status == :ok
    assert aprogress == eprogress
  end

  # TODO test for completed pieces

  test "Changing state when a piece is needed", context do
    ttinfo = %TorrentTrackingInfo{
      context.example_ttinfo
      | need_piece: false
    }

    assert TorrentTrackingInfo.is_piece_needed(ttinfo) == false

    {:ok, new_ttinfo} = TorrentTrackingInfo.mark_piece_needed(ttinfo)

    assert TorrentTrackingInfo.is_piece_needed(new_ttinfo) == true
  end

  # TODO test for addition to piece data blocks

  defp setup_torrent(context) do
    {:ok, resp} = @server_impl.add_new_torrent(@server_name, @file_name_1)

    %TorrentTrackingInfo{
      context.example_ttinfo
      | id: Map.get(resp, "torrent id")
    }
  end
end
