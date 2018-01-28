defmodule BittorrentClient.HTTPHandle.InMemoryImpl do
  @moduledoc """
  In memory implementation of the HTTPHandle behaviour for testing locally
  """
  @behaviour BittorrentClient.HTTPHandle
  alias BittorrentClient.Logger.Factory, as: LoggerFactory
  alias BittorrentClient.Logger.JDLogger, as: JDLogger
  @logger LoggerFactory.create_logger(__MODULE__)

  def get(_url, _headers, []) do
    JDLogger.warn(@logger, "Using #{__MODULE__} implementation for HTTPoison.get")
    {:error,
     %HTTPoison.Error{__exception__: nil, id: nil, reason: "Empty opts?"}}
  end

  def get(_url, headers, opts) do
    # get example for test files
    JDLogger.warn(@logger, "Using #{__MODULE__} implementation for HTTPoison.get")
    {:ok,
     %HTTPoison.Response{
       body: "",
       headers: headers,
       status_code: 200
     }}
  end
end
