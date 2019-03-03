defmodule BittorrentClient.Cache.MnesiaImpl do
  @moduledoc false
  @behaviour BittorrentClient.Cache
  use GenServer
  require Logger

  @cache_prefix :btc_mnesia_cache

  # -------------------------------------------------------------------------------
  # GenServer Callbacks
  # -------------------------------------------------------------------------------
  def start_link(name, opts) do
    Logger.info(
      "Starting BTC Mnesia Cache for #{inspect(name)} with #{inspect(opts)}"
    )

    GenServer.start_link(
      __MODULE__,
      {name, opts},
      name: {:global, {@cache_prefix, name}}
    )
  end

  def init({name, opts}) do
    case :mnesia.create_table(name, opts) do
      {:atomic, :ok} ->
        {:ok, {name, opts}}

      {:aborted, reason} ->
        Logger.error(
          "Failed to create Cache for #{inspect(name)} : #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def handle_call({:get_all}, _from, {name, opts}) do
    trans = fn ->
      name
      |> :mnesia.all_keys()
      |> Enum.reduce({:ok, []}, fn elem, {check, ret} ->
        retrieve_key_info({name, opts}, elem, check, ret)
      end)
    end

    case :mnesia.transaction(trans) do
      {:atomic, {:ok, result}} ->
        {:reply, {:ok, result}, {name, opts}}

      {:aborted, reason} ->
        Logger.error(
          "Cache for #{inspect(name)} failed to get all elements : #{
            inspect(reason)
          }"
        )

        {:reply, {:error, reason}, {name, opts}}
    end
  end

  defp retrieve_key_info({name, opts}, elem, check, ret) do
    if check == :aborted do
      {check, ret}
    else
      case :mnesia.read({name, elem}) do
        {:aborted, reason} ->
          Logger.error("#{inspect(name)} Failed to retrieve #{inspect(elem)}")

          {:aborted, reason}

        [{_serv, key, val} | _rst] ->
          {check, ret ++ [{key, val}]}
      end
    end
  end

  def handle_call({:get, key}, _from, {name, opts}) do
    trans = fn ->
      :mnesia.read({name, key})
    end

    case :mnesia.transaction(trans) do
      {:atomic, []} ->
        reason = "Does not exist"

        Logger.error(
          "Cache for #{inspect(name)} failed to get #{key} : #{reason}"
        )

        {:reply, {:error, reason}, {name, opts}}

      {:atomic, [{_serv, key, val} | _rst]} ->
        {:reply, {:ok, [{key, val}]}, {name, opts}}

      {:aborted, reason} ->
        Logger.error(
          "Cache for #{inspect(name)} failed to get #{key} : #{inspect(reason)}"
        )

        {:reply, {:error, reason}, {name, opts}}
    end
  end

  def handle_call({:set, key, val}, _from, {name, opts}) do
    trans = fn ->
      :mnesia.write({name, key, val})
    end

    case :mnesia.transaction(trans) do
      {:atomic, :ok} ->
        {:reply, :ok, {name, opts}}

      {:aborted, reason} ->
        Logger.error(
          "Cache for #{inspect(name)} failed to set #{key} : #{inspect(reason)}"
        )

        {:reply, {:error, reason}, {name, opts}}
    end
  end

  def handle_call({:delete, key}, _from, {name, opts}) do
    trans = fn ->
      :mnesia.delete({name, key})
    end

    case :mnesia.transaction(trans) do
      {:atomic, :ok} ->
        {:reply, :ok, {name, opts}}

      {:aborted, reason} ->
        Logger.error(
          "Cache for #{inspect(name)} failed to delete #{key} : #{
            inspect(reason)
          }"
        )

        {:reply, {:error, reason}, {name, opts}}
    end
  end

  def handle_call({:get_configuration}, _from, {name, opts}) do
    {:reply, {:ok, opts}, {name, opts}}
  end

  # -------------------------------------------------------------------------------
  # API
  # -------------------------------------------------------------------------------
  def new(ref, opts \\ []) do
    __MODULE__.start_link(ref, opts)
  end

  def set(cache_ref, key, val) do
    Logger.debug(fn -> "Entered set function for #{cache_ref}" end)

    GenServer.call(
      :global.whereis_name({@cache_prefix, cache_ref}),
      {:set, key, val}
    )
  end

  def get(cache_ref, key) do
    Logger.debug(fn -> "Entered get function for #{cache_ref}" end)

    GenServer.call(
      :global.whereis_name({@cache_prefix, cache_ref}),
      {:get, key}
    )
  end

  def delete(cache_ref, key) do
    Logger.debug(fn -> "Entered delete function for #{cache_ref}" end)

    GenServer.call(
      :global.whereis_name({@cache_prefix, cache_ref}),
      {:delete, key}
    )
  end

  def get_all(cache_ref) do
    Logger.debug(fn -> "Entered get_all function for #{cache_ref}" end)

    GenServer.call(
      :global.whereis_name({@cache_prefix, cache_ref}),
      {:get_all}
    )
  end

  def get_configuration(cache_ref) do
    Logger.debug(fn -> "Enetered get_configuration for #{cache_ref}" end)

    GenServer.call(
      :global.whereis_name({@cache_prefix, cache_ref}),
      {:get_configuration}
    )
  end

  # -------------------------------------------------------------------------------
  # Utility functions
  # -------------------------------------------------------------------------------
end
