defmodule BittorrentClient.Cache do
  @moduledoc """
  """
  @type reason :: String.t()
  @type key :: tuple()
  @type cache_ref :: atom() | String.t() | pid()

  @doc """
  Creates a new cache
  """
  @callback new(cache_ref, [any()]) :: {:ok, pid} | {:error, reason}

  @doc """
  Retrieves value for a given key from cache, 
  returns error if the given key does not exist
  """
  @callback get(cache_ref, key) :: {:ok, any()} | {:error, :not_found}

  @doc """
  Sets value for a given key, 
  returns error if the given key could not be set
  """
  @callback set(cache_ref, key, value :: any()) :: :ok | {:error, reason}

  @doc """
  Returns all the contents of the given cache
  """
  @callback getAll() :: [tuple()]

  @doc """
  Deletes given key from cache
  """
  @callback delete(cache_ref, key) :: :ok
end
