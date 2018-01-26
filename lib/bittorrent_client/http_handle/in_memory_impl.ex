defmodule BittorrentClient.HTTPHandle.InMemoryImpl do
  @moduledoc """
  In memory implementation of the HTTPHandle behaviour for testing locally
  """
  @behaviour BittorrentClient.HTTPHandle

  def get(_url, _headers, []) do
    {:error,
     %HTTPoison.Error{__exception__: nil, id: nil, reason: "Empty opts?"}}
  end

  def get(_url, headers, opts) do
    # get example for test files
    {:ok,
     %HTTPoison.Response{
       body: "",
       headers: headers,
       status_code: 200
     }}
  end
end
