defmodule BittorrentClient.Cache.ETSImpl do
  @moduledoc """
  """
  @behaviour BittorrentClient.Cache
  use GenServer
  require Logger

  @cache_prefix :btc_ets_cache

  # -------------------------------------------------------------------------------
  # GenServer Callbacks
  # -------------------------------------------------------------------------------
  def start_link(name, opts) do
    Logger.info("Starting BTC ETS Cache for #{name}")

    GenServer.start_link(
      __MODULE__,
      {name, opts},
      name: {:global, {@cache_prefix, name}}
    )
  end

  def init({name, opts}) do
    tab = :ets.new(name, opts)
    {:ok, {name, tab}}
  end

  # -------------------------------------------------------------------------------
  # API
  # -------------------------------------------------------------------------------
  def new(ref, opts \\ []) do
    __MODULE__.start_link(ref, opts)
  end

  def set(cache_ref, key, val) do
    Logger.debug("Entered set function for #{cache_ref}")

    GenServer.call(
      :global.whereis_name({@cache_prefix, cache_ref}),
      {:set, key, val}
    )
  end

  def get(cache_ref, key) do
    Logger.debug("Entered get function for #{cache_ref}")

    GenServer.call(
      :global.whereis_name({@cache_prefix, cache_ref}),
      {:get, key}
    )
  end

  def delete(cache_ref, key) do
    Logger.debug("Entered delete funcion for #{cache_ref}")

    GenServer.call(
      :global.whereis_name({@cache_prefix, cache_ref}),
      {:delete, key}
    )
  end

  def get_all(cache_ref) do
    Logger.debug("Entered get_all function for #{cache_ref}")

    GenServer.call(
      :global.whereis_name({@cache_prefix, cache_ref}),
      {:get_all}
    )
  end

  # -------------------------------------------------------------------------------
  # Utility functions
  # -------------------------------------------------------------------------------
end
