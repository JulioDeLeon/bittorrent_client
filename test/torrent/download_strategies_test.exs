defmodule BittorrentClient.Torrent.DownloadStrategies.Test do
  use ExUnit.Case
  alias BittorrentClient.Torrent.DownloadStrategies, as: DownloadStrategies

  setup_all do
    piece_table = %{
      0 => {:completed, 1, <<>>},
      1 => {:found, 3, <<>>},
      2 => {:found, 2, <<>>},
      4 => {:in_progress, 2, <<>>},
      5 => {:found, 1, <<>>}
    }

    {:ok,
     [
       piece_table: piece_table
     ]}
  end

  test "determine correct piece with rarest strategy", context do
    indexes = [0, 1, 2, 3, 4]

    {:ok, index} =
      DownloadStrategies.determine_next_piece(
        :rarest_piece,
        context.piece_table,
        indexes
      )

    assert(index == 2)

    indexes = [0, 1, 2, 3, 4, 5]

    {:ok, index} =
      DownloadStrategies.determine_next_piece(
        :rarest_piece,
        context.piece_table,
        indexes
      )

    assert(index == 5)
  end

  test "determine correct piece with default (in-order) strategy", context do
    indexes = [0, 1, 2, 3, 4, 5]

    {:ok, index} =
      DownloadStrategies.determine_next_piece(
        :in_order,
        context.piece_table,
        indexes
      )

    assert index == 1
  end

  test "handle empty piece table when determining next piece" do
    indexes = [1, 2, 3, 4, 5]

    {status, _} =
      DownloadStrategies.determine_next_piece(:rarest_piece, %{}, indexes)

    assert status == :error
  end

  test "handle empty index list when determining next piece", context do
    {status, _} =
      DownloadStrategies.determine_next_piece(
        :rarest_piece,
        context.piece_table,
        []
      )

    assert status == :error
  end
end
