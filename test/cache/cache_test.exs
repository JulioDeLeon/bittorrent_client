defmodule BittorrentClient.CacheTest do
  defmacro __using__(options) do
    quote do
      use ExUnit.Case
      @moduletag unquote(options)

      setup %{cache_impl: cache_impl, cache_ref: cache_ref, cache_opts: cache_opts} do
        on_exit fn  ->
          {:ok, elems} = cache_impl.get_all(cache_ref)
          if length(elems) > 0 do
            Enum.map(elems, fn {key, val} ->
              cache_impl.delete(cache_ref, key)
            end)
          end
        end
      end

      test "addition of item into cache", %{cache_impl: cache_impl, cache_ref: cache_ref, cache_opts: cache_opts} do
        e_key = "key"
        e_val = "val"
        {:ok, elems} = cache_impl.get_all(cache_ref)
        assert elems == []
        assert cache_impl.set(cache_ref, e_key, e_val) == :ok
        {status, [{key, val}]} = cache_impl.get(cache_ref, e_key)
        assert status == :ok
        assert val == e_val
      end

      test "lookup of non-exisitent object in cache", %{cache_impl: cache_impl, cache_ref: cache_ref, cache_opts: cache_opts} do
        e_key = "doesnotexist"
        {status, _reason} = cache_impl.get(cache_ref, e_key)
        assert status == :error
      end

      test "addition of duplicate objects in cache", %{cache_impl: cache_impl, cache_ref: cache_ref, cache_opts: cache_opts} do
        e_key = "key"
        e_val = "val"
        :ok = cache_impl.set(cache_ref, e_key, e_val)
        {:ok, [{a_key, a_val}]} = cache_impl.get(cache_ref, e_key)
        assert a_key == e_key
        assert a_val == e_val
        new_val = "new_val"
        :ok = cache_impl.set(cache_ref, e_key, new_val)
        {:ok, [{a_key, a_val}]} = cache_impl.get(cache_ref, e_key)
        assert a_key == e_key
        assert a_val == new_val
      end

      test "removal of an object from cache",  %{cache_impl: cache_impl, cache_ref: cache_ref, cache_opts: cache_opts} do
        e_key = "key"
        e_val = "val"
        :ok = cache_impl.set(cache_ref, e_key, e_val)
        {status, [{a_key, a_val}]} = cache_impl.get(cache_ref, e_key)
        assert status == :ok
        assert a_key == e_key
        assert a_val == e_val
        _status = cache_impl.delete(cache_ref, e_key)
        {status, _reason} = cache_impl.get(cache_ref, e_key)
        assert status == :error
      end

      test "get all items in cache",  %{cache_impl: cache_impl, cache_ref: cache_ref, cache_opts: cache_opts} do
        assert true
      end
    end
  end
end


defmodule BittorrentClient.CacheTest.ETSImpl do
  use ExUnit.Case
  @cache_impl BittorrentClient.Cache.ETSImpl
  @cache_ref :some_name
  @cache_opts []
  use BittorrentClient.CacheTest, cache_impl: @cache_impl, cache_ref: @cache_ref, cache_opts: @cache_opts

  setup_all context do
    {:ok, _pid} = @cache_impl.start_link(@cache_ref, @cache_opts)
    :ok
  end
end

defmodule BittorrentClient.CacheTest.MnesiaImpl do
  use ExUnit.Case
  @cache_impl BittorrentClient.Cache.MnesiaImpl
  @cache_ref :some_name
  @cache_opts []
  use BittorrentClient.CacheTest, cache_impl: BittorrentClient.Cache.MnesiaImpl, cache_ref: :some_name, cache_opts: []

  setup_all do
    {:ok, _pid} = @cache_impl.start_link(@cache_ref, @cache_opts)
    :ok
  end
end

