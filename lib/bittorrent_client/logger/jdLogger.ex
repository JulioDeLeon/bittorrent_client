defmodule BittorrentClient.Logger.JDLogger do
  @moduledoc """
  Wraps logger to include __MODULE__ inline. Currently not as configurable as
  base logger library.
  """

  require Logger

  @derive {Poison.Encoder, except: []}
  defstruct [:module_name]

  @type __MODULE__ :: %__MODULE__{
          module_name: String.t()
        }

  def debug(data, msg) do
    Logger.debug(fn ->
      "[#{Map.get(data, :module_name)}] [#{inspect(self())}] #{msg}"
    end)
  end

  def info(data, msg) do
    Logger.info(fn ->
      "[#{Map.get(data, :module_name)}] [#{inspect(self())}] #{msg}"
    end)
  end

  def error(data, msg) do
    Logger.error(fn ->
      "[#{Map.get(data, :module_name)}] [#{inspect(self())}] #{msg}"
    end)
  end

  def warn(data, msg) do
    Logger.warn(fn ->
      "[#{Map.get(data, :module_name)}] [#{inspect(self())}] #{msg}"
    end)
  end
end
