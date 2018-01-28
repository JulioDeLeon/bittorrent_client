defmodule BittorrentClient.HTTPHandle.HTTPoisonImpl do
  @moduledoc """
  HTTPoison implementation of HTTPhandle, meant for real world use
  """
  alias BittorrentClient.Logger.Factory, as: LoggerFactory
  alias BittorrentClient.Logger.JDLogger, as: JDLogger
  @logger LoggerFactory.create_logger(__MODULE__)

  def get(url, headers, opts) do
    JDLogger.debug(@logger, "URL #{inspect url}, HEADERS #{inspect headers}, OPTS #{inspect opts}")
    HTTPoison.get(url, headers, opts)
  end
end
