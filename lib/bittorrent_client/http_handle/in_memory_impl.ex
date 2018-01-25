defmodule BittorrentClient.HTTPHandle.InMemoryImpl do
  @moduledoc """
  In memory implementation of the HTTPHandle behaviour for testing locally
  """
  @behaviour BittorrentClient.HTTPHandle

  def get(_url, headers, _opts) do
    #get example for test files
    %HTTPoison.Response{
      body: "",
      headers: headers,
      status_code: 200
    }
  end
end
