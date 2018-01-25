defmodule BittorrentClient.HTTPHandle do
  @moduledoc """
  This module is meant to wrap HTTPoison for testing purposes.
  """

  @doc """
  Issues a GET request to the given url.
  """
  @callback get(url :: binary(), headers :: [HTTPoison.headers()], opts :: [Keyword.t]) :: {:ok, HTTPoison.Response.t | HTTPoison.AsyncResponse.t} | {:error, HTTPoison.Error.t}
end
