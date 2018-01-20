defmodule BittorrentClient.ServerTest do
  use ExUnit.Case
  @server_impl Application.get_env(:bittorrent_client, :server_impl)
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

    on_exit fn ->
      IO.puts "#{__MODULE__} on_exit"
      :ok
    end

    {:ok, [file_1_bento_contents: file_1_bento_contents,
           file_2_bento_contents: file_2_bento_contents]}
  end

  test "Addition of a new torrent on the Server layer", context do
    {status, data} = @server_impl.add_new_torrent(@server_name, @file_name_1)
    assert status == :ok
  end
end
