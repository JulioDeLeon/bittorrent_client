defmodule BittorrentClient.Server.Test do
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

  test "Server.whereis returnes a pid when looking for valid server name from Server layer" do
    assert is_pid(@server_impl.whereis(@server_name))
  end

  test "Server.whereis returns :undefined when given a invalid server name from Server layer" do
    fake_server_name = "not real"
    assert !is_pid(@server_impl.whereis(fake_server_name))
    assert @server_impl.whereis(fake_server_name) == :undefined
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

    deleted_id =
      ret_data
      |> Map.get("data")
      |> Map.get(:id)

    assert deleted_id == torrent_id

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

    {delete_all_status, _data} = @server_impl.delete_all_torrents(@server_name)
    assert delete_all_status == :ok
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
      |> Map.get(:status)

    curr_id =
      torrent_info
      |> Map.get("data")
      |> Map.get(:id)

    assert curr_status == :initial
    assert curr_id == torrent_id

    metadata = Map.get(torrent_info, "metadata")

    assert compare_bento_data_to_metadata(
             context.file_2_bento_contents,
             metadata
           )

    {update_status, ret_data} =
      @server_impl.update_torrent_status_by_id(
        @server_name,
        torrent_id,
        expected_status
      )

    assert update_status == :ok

    new_status =
      ret_data
      |> Map.get("data")
      |> Map.get(:status)

    curr_id =
      ret_data
      |> Map.get("data")
      |> Map.get(:id)

    assert new_status == expected_status
    assert curr_id == torrent_id

    {second_torrent_info_status, new_torrent_info} =
      @server_impl.get_torrent_info_by_id(@server_name, torrent_id)

    assert second_torrent_info_status == :ok
    assert Map.has_key?(new_torrent_info, "data")
    assert Map.has_key?(new_torrent_info, "metadata")

    new_meta_data = Map.get(new_torrent_info, "metadata")

    assert compare_bento_data_to_metadata(
             context.file_2_bento_contents,
             new_meta_data
           )

    new_torrent_status = Map.get(new_torrent_info, "data").status
    assert new_torrent_status == expected_status
  end

  test "Addition of the same torrent file will fail from the Server Layer",
       _context do
    {add_torrent_status, _resp_map} =
      @server_impl.add_new_torrent(@server_name, @file_name_1)

    assert add_torrent_status == :ok

    {add_torrent_status_2, _resp_map} =
      @server_impl.add_new_torrent(@server_name, @file_name_1)

    assert add_torrent_status_2 == :error
  end

  test "Updating status of a torrent process that does not exist from Server layer" do
    {update_status, _msg} =
      @server_impl.update_torrent_status_by_id(
        @server_name,
        "fake id",
        :some_status
      )

    assert update_status == :error
  end

  test "Add a torrent file that does not exist from the Server layer" do
    {add_status, _msg} = @server_impl.add_new_torrent(@server_name, "some_file")
    assert add_status == :error
  end

  test "Deletion of a torrent process that does not exist" do
    some_torrent_id = "superfake"
    assert @torrent_impl.whereis(some_torrent_id) == :undefined

    {deletion_status, _msg} =
      @server_impl.delete_torrent_by_id(@server_name, some_torrent_id)

    assert deletion_status == :error
  end

  test "Connect a torrent to its respective tracker from the Server Layer" do
    {add_torrent_status, resp_map} =
      @server_impl.add_new_torrent(@server_name, @file_name_2)

    assert add_torrent_status == :ok
    torrent_id = Map.get(resp_map, "torrent id")

    {status, _ret} =
      @server_impl.connect_torrent_to_tracker(@server_name, torrent_id)

    assert status == :ok
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
