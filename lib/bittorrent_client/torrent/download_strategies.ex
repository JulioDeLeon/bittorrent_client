defmodule BittorrentClient.Torrent.DownloadStrategies do
  @moduledoc """
  This module implements multiple strategies for torrent process to use when determing how to download related pieces.
  """
  require Logger

  @spec needs_work?(map(), integer()) :: boolean()
  defp needs_work?(piece_table, index) do
    if Map.has_key?(piece_table, index) do
      {status, _, _} = Map.get(piece_table, index)
      status == :found
    else
      false
    end
  end

  @spec determine_next_piece(atom(), map(), list(integer())) ::
          {:ok, integer()} | {:error, binary()}
  def determine_next_piece(_, _, []) do
    {:error, "no indexes were received"}
  end

  def determine_next_piece(_, piece_table, _) when piece_table == %{} do
    {:error, "empty piece table, cannot determine next piece"}
  end

  def determine_next_piece(:rarest_piece, piece_table, indexes) do
    get_ref_count = fn i ->
      {_, ref_count, _} = Map.get(piece_table, i)
      ref_count
    end

    possible_indexes =
      indexes
      |> Stream.filter(fn x -> Map.has_key?(piece_table, x) end)
      |> Stream.filter(fn x -> needs_work?(piece_table, x) end)
      |> Enum.to_list()
      |> Enum.sort_by(get_ref_count)

    case possible_indexes do
      [] ->
        {:error, "no indexes available"}

      [ret | _rst] ->
        {:ok, ret}
    end
  end

  def determine_next_piece(_, piece_table, indexes) do
    Logger.info("Using default strategy : In-Order strategy")

    possible_indexes =
      indexes
      |> Stream.filter(fn x -> Map.has_key?(piece_table, x) end)
      |> Stream.filter(fn x -> needs_work?(piece_table, x) end)
      |> Enum.to_list()
      |> Enum.sort()

    case possible_indexes do
      [] ->
        {:error, "no indexes available"}

      [ret | _rst] ->
        {:ok, ret}
    end
  end
end
