defmodule BittorrentClient.Torrent.Test do
  use ExUnit.Case
  doctest BittorrentClient.Server.GenServerImpl
  @torrent_impl Application.compile_env(:bittorrent_client, :torrent_impl)
  @server_impl Application.compile_env(:bittorrent_client, :server_impl)
  @server_name Application.compile_env(:bittorrent_client, :server_name)
  @file_name_1 "priv/ubuntu.torrent"
  @file_name_2 "priv/arch.torrent"

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

  test "whereis should return a valid pid from Torrent layer", _context do
    {add_status, data} =
      @server_impl.add_new_torrent(@server_name, @file_name_1)

    assert add_status == :ok
    torrent_pid = Map.get(data, "torrent id")

    assert is_pid(@torrent_impl.whereis(torrent_pid))
  end

  test "whereis should return undefined when given invalid id from Torrent layer",
       _context do
    assert @torrent_impl.whereis("fake id") == :undefined
  end

  test "Return expected torrent data on an existing torrent process from Torrent Layer",
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

  test "resets :started piece back to :found when owning peer process exits" do
    {:ok, data} = @server_impl.add_new_torrent(@server_name, @file_name_1)
    torrent_id = Map.get(data, "torrent id")

    {:ok, _} = @torrent_impl.add_new_piece_index(torrent_id, "peer_1", 0)
    {:ok, _} = @torrent_impl.add_new_piece_index(torrent_id, "peer_2", 0)

    parent = self()

    peer_pid =
      spawn(fn ->
        {:ok, 0} = @torrent_impl.get_next_piece_index(torrent_id, [0])
        send(parent, :acquired)

        receive do
          :exit -> :ok
        end
      end)

    assert_receive :acquired, 1_000

    # While peer_pid holds piece 0 (:started), another peer cannot acquire it
    assert {:error, _} = @torrent_impl.get_next_piece_index(torrent_id, [0])

    send(peer_pid, :exit)
    Process.sleep(50)

    # After peer_pid exits, piece 0 is reset to :found and can be acquired again
    assert {:ok, 0} = @torrent_impl.get_next_piece_index(torrent_id, [0])
  end

  test "get_completed_piece_list returns completed pieces" do
    {:ok, data} = @server_impl.add_new_torrent(@server_name, @file_name_1)
    torrent_id = Map.get(data, "torrent id")
    {:ok, []} = @torrent_impl.get_completed_piece_list(torrent_id)
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
