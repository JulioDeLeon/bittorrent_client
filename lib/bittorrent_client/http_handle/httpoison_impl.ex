defmodule BittorrentClient.HTTPHandle.HTTPoisonImpl do
  @moduledoc """
  HTTPoison implementation of HTTPhandle, meant for real world use
  """
  require Logger

  def get(url, headers, opts) do
    Logger.debug(
      "URL #{inspect(url)}, HEADERS #{inspect(headers)}, OPTS #{inspect(opts)}"
    )

    HTTPoison.get(url, headers, opts)
  end
end
