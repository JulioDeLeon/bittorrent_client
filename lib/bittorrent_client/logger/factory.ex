defmodule BittorrentClient.Logger.Factory do
  @moduledoc """
  Creates a wrapper for the default logger to include __MODULE__ inline as well.
  """
  alias BittorrentClient.Logger.JDLogger, as: JDLogger

  def create_logger(mod_name, compact \\ false) do
    new_string =
      if compact do
        pack_module_name(mod_name)
      else
        mod_name
      end

    %JDLogger{
      module_name: new_string
    }
  end

  defp pack_module_name(mod_name) do
    parts = String.split(mod_name, ".")

    firsts_parts =
      parts
      |> Enum.take(Enum.count(parts) - 1)
      |> Enum.map(fn x -> String.at(x, 0) end)

    last = List.last(parts)
    Enum.join(Enum.concat(firsts_parts, [last]), ".")
  end
end
