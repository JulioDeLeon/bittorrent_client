defmodule TorrentTest do
  use ExUnit.Case
  doctest BittorrentClient.Server.GenServerImpl
  @torrent_impl Application.get_env(:bittorrent_client, :torrent_impl)
  @server_impl Application.get_env(:bittorrent_client, :server_impl)
  @server_name Application.get_env(:bittorrent_client, :server_name)
  @file_name_1 "priv/ubuntu.torrent"
  @file_name_2 "priv/arch.torrent"
  alias BittorrentClient.Torrent.Supervisor, as: TorrentSupervisor

  setup_all do
    file_1_bento_contents =
      @file_name_1
      |> File.read!()
      |> Bento.decode!()

    file_2_bento_contents =
      @file_name_2
      |> File.read!()
      |> Bento.decode!()

    {:ok,
     [
       file_1_bento_contents: file_1_bento_contents,
       file_2_bento_contents: file_2_bento_contents
     ]}
  end

  setup do
    on_exit(fn ->
      _ret = @server_impl.delete_all_torrents(@server_name)
    end)
  end

  test "whereis should return a valid pid from Torrent layer", context do
    {add_status, data} =
      @server_impl.add_new_torrent(@server_name, @file_name_1)

    assert add_status == :ok
    torrent_pid = Map.get(data, "torrent id")

    assert is_pid(@torrent_impl.whereis(torrent_pid))
  end

  test "whereis should return undefined when given invalid id from Torrent layer",
       context do
    assert @torrent_impl.whereis("fake id") == :undefined
  end

  test "Return expected torrent data on an exisiting torrent process from Torrent Layer",
       context do
    {add_status, data} =
      @server_impl.add_new_torrent(@server_name, @file_name_1)

    assert add_status == :ok
    torrent_id = Map.get(data, "torrent id")
    {get_status, data} = @torrent_impl.get_torrent_data(torrent_id)
    assert get_status == :ok

    assert compare_bento_data_to_metadata(
             context.file_2_bento_contents,
             Map.get(data, "metadata")
           )
  end

  defp compare_bento_data_to_metadata(bento_data, metadata) do
    Enum.reduce(Map.keys(bento_data), true, fn key, acc ->
      bento_field_val = Map.get(bento_data, key)

      case Map.has_key?(metadata, key) do
        false ->
          acc

        true ->
          metadata_field_val = Map.get(metadata, key)
          acc && bento_field_val == metadata_field_val
      end
    end)
  end
end
