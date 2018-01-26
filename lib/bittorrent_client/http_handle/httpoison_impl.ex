defmodule BittorrentClient.HTTPHandle.HTTPoisonImpl do
  @moduledoc """
  HTTPoison implementation of HTTPhandle, meant for real world use
  """

  def get(url, headers, opts) do
    HTTPoison.get(url, headers, opts)
  end
end
