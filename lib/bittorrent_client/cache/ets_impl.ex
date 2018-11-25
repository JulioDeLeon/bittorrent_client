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
    Logger.info("Starting BTC ETS Cache for #{inspect name} with #{inspect opts}")

    GenServer.start_link(
      __MODULE__,
      {name, opts},
      name: {:global, {@cache_prefix, name}}
    )
  end

  def init({name, opts}) do
    table_ref = :ets.new(name, opts)
    {:ok, {name, table_ref, opts}}
  end

  def handle_call({:get_all}, _from, {name, table_ref, opts}) do
    {:reply, {:ok, :ets.tab2list(table_ref)}, {name, table_ref, opts}}
  end

  def handle_call({:set, key, val}, _from, {name, table_ref, opts}) do
    case :ets.lookup(table_ref, key) do
      [] ->
        Logger.debug("#{inspect name} does not have #{inspect key}, creating a new key")
        check = :ets.insert_new(table_ref, {key, val})
        {:reply, {:ok, check}, {name, table_ref, opts}}
      _ ->
        Logger.debug("#{inspect name} will override #{inspect key}")
        check = :ets.insert(table_ref, {key, val})
        {:reply, {:ok, check}, {name, table_ref, opts}}
    end
  end

  def handle_call({:get, key}, _from, {name, table_ref, opts}) do
    case :ets.lookup(table_ref, key) do
      [] ->
        msg = "#{inspect name} does not contain #{inspect key}"
        Logger.error(msg)
        {:reply, {:error, msg}, {name, table_ref, opts}}
      ret ->
        {:reply, {:ok, ret}, {name, table_ref, opts}}
    end
  end

  def handle_call({:delete, key}, _from, {name, table_ref, opts}) do
    {:reply, {:ok, :ets.delete(table_ref, key)}, {name, table_ref, opts}}
  end

  def handle_call({:get_configuration}, _from, {name, table_ref, opts}) do
    {:reply, {:ok, opts}, {name, table_ref, opts}}
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

  def get_configuration(cache_ref) do
    Logger.debug("Entered get_configuration for #{cache_ref}")

    GenServer.call(
      :global.whereis_name({@cache_prefix, cache_ref}),
      {:get_configuration}
   )
  end
  # -------------------------------------------------------------------------------
  # Utility functions
  # -------------------------------------------------------------------------------
end
