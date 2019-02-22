defmodule BittorrentClient.Torrent.DownloadStrategies do
  require Logger

  @spec needs_work?(map(), integer()) :: boolean()
  defp needs_work?(piece_table, index) do
    if !Map.has_key?(piece_table, index) do
      false
    else
      {status, _} = Map.get(piece_table, index)
      status == :found
    end
  end

  @spec determine_next_piece(atom(), map(), list(integer())) ::
          {:ok, integer()} | {:error, binary()}
  def determine_next_piece(_, _, []) do
    {:error, "no index were received"}
  end

  def determine_next_piece(_, piece_table, _) when piece_table == %{} do
    {:error, "empty piece table, cannot determine next piece"}
  end

  def determine_next_piece(:rarest_piece, piece_table, indexes) do
    get_ref_count = fn i ->
      {_, ref_count} = Map.get(piece_table, i)
      ref_count
    end

    [ret | _rst] =
      indexes
      |> Enum.filter(fn x -> Map.has_key?(piece_table, x) end)
      |> Enum.filter(fn x -> needs_work?(piece_table, x) end)
      |> Enum.sort_by(get_ref_count)

    {:ok, ret}
  end

  def determine_next_piece(_, piece_table, indexes) do
    Logger.info("Using default strategy : In-Order strategy")

    [ret | _rst] =
      indexes
      |> Enum.filter(fn x -> Map.has_key?(piece_table, x) end)
      |> Enum.filter(fn x -> needs_work?(piece_table, x) end)
      |> Enum.sort()

    {:ok, ret}
  end
end