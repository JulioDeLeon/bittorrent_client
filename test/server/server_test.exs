defmodule ServerTest do
  use ExUnit.Case
  @server_impl Application.get_env(:bittorrent_client, :server_impl)
  @torrent_impl Application.get_env(:bittorrent_client, :torrent_impl)
  @server_name Application.get_env(:bittorrent_client, :server_name)
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

  test "Addition of a new torrent from Server layer", context do
    {add_torrent_status, resp_map} =
      @server_impl.add_new_torrent(@server_name, @file_name_1)

    assert add_torrent_status == :ok
    torrent_id = Map.get(resp_map, "torrent id")

    {list_torrent_status, torrent_table} =
      @server_impl.list_current_torrents(@server_name)

    #    IO.inspect torrent_table
    assert list_torrent_status == :ok
    assert Map.has_key?(torrent_table, torrent_id)

    torrent_entry = Map.get(torrent_table, torrent_id)
    assert Map.has_key?(torrent_entry, "data")
    assert Map.has_key?(torrent_entry, "metadata")

    metadata = Map.get(torrent_entry, "metadata")

    assert compare_bento_data_to_metadata(
             context.file_1_bento_contents,
             metadata
           )
  end

  test "Deletion of single torrent from Server Layer", context do
    {add_torrent_status, resp_map} =
      @server_impl.add_new_torrent(@server_name, @file_name_2)

    assert add_torrent_status == :ok
    torrent_id = Map.get(resp_map, "torrent id")

    {torrent_info_status, torrent_info} =
      @server_impl.get_torrent_info_by_id(@server_name, torrent_id)

    assert torrent_info_status == :ok
    assert Map.has_key?(torrent_info, "data")
    assert Map.has_key?(torrent_info, "metadata")

    metadata = Map.get(torrent_info, "metadata")

    assert compare_bento_data_to_metadata(
             context.file_2_bento_contents,
             metadata
           )

    {deletion_status, ret_data} =
      @server_impl.delete_torrent_by_id(@server_name, torrent_id)

    assert deletion_status == :ok

    pid = @torrent_impl.whereis(torrent_id)
    assert pid == :undefined

    {list_torrent_status, torrent_table} =
      @server_impl.list_current_torrents(@server_name)

    assert list_torrent_status == :ok
    assert Map.has_key?(torrent_table, torrent_id) == false
  end

  test "Deletion of all torrents from the Server Layer" do
    {add_torrent_status, resp_map} =
      @server_impl.add_new_torrent(@server_name, @file_name_1)

    assert add_torrent_status == :ok
    torrent_id = Map.get(resp_map, "torrent id")

    {add_torrent_status_2, resp_map_2} =
      @server_impl.add_new_torrent(@server_name, @file_name_2)

    assert add_torrent_status_2 == :ok
    torrent_id_2 = Map.get(resp_map_2, "torrent id")

    {list_current_status, torrent_table} =
      @server_impl.list_current_torrents(@server_name)

    assert list_current_status == :ok
    assert Map.has_key?(torrent_table, torrent_id)
    assert Map.has_key?(torrent_table, torrent_id_2)

    {delete_all_status, data} = @server_impl.delete_all_torrents(@server_name)
    assert delete_all_status == :ok
    IO.puts("Ret from delete all: #{inspect(data)}")
    assert @torrent_impl.whereis(torrent_id) == :undefined
    assert @torrent_impl.whereis(torrent_id_2) == :undefined

    {list_current_status, torrent_table} =
      @server_impl.list_current_torrents(@server_name)

    assert list_current_status == :ok
    assert torrent_table == %{}
  end

  test "Updating torrent status by id at the Server Layer", context do
    expected_status = :started
    {add_torrent_status, resp_map} =
      @server_impl.add_new_torrent(@server_name, @file_name_1)

    assert add_torrent_status == :ok
    torrent_id = Map.get(resp_map, "torrent id")

    {torrent_info_status, torrent_info} =
      @server_impl.get_torrent_info_by_id(@server_name, torrent_id)

    assert torrent_info_status == :ok
    assert Map.has_key?(torrent_info, "data")
    assert Map.has_key?(torrent_info, "metadata")

    curr_status =
      torrent_info
      |> Map.get("data")
      |> Map.get("status")

    metadata = Map.get(torrent_info, "metadata")

    assert compare_bento_data_to_metadata(
      context.file_2_bento_contents,
      metadata
    )

    {update_status, ret_data} = @server_impl.update_torrent_status_by_id(@server_name, torrent_id, expected_status)

    assert update_status == :ok
    IO.inspect ret_data

    {second_torrent_info_status, new_torrent_info} = @server_impl.get_torrent_info_by_id(@server_name, torrent_id)
    assert second_torrent_info_status == :ok
    assert Map.has_key?(new_torrent_info, "data")
    assert Map.has_key?(new_torrent_info, "metadata")
    IO.inspect new_torrent_info

    new_meta_data = Map.get(new_torrent_info, "metadata")
    assert compare_bento_data_to_metadata(context.file_2_bento_contents, new_meta_data)

    new_torrent_status = Map.get(new_torrent_info, "data").status
    assert new_torrent_status == expected_status
  end

  # TODO: Write test for connecting to tracker and starting torrent logic
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
