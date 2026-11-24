defmodule BittorrentClient.Torrent.FileAssemblerTest do
  use ExUnit.Case
  alias BittorrentClient.Torrent.FileAssembler

  @torrent_cache_name Application.get_env(
                        :bittorrent_client,
                        :torrent_cache_name
                      )

  setup do
    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "btc_assembler_test_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(tmp_dir)

    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir}
  end

  test "assembles single-file torrent with shorter last piece", %{tmp_dir: tmp_dir} do
    src_file = "single_#{System.unique_integer([:positive])}.torrent"
    piece0 = :binary.copy(<<1>>, 10)
    piece1 = :binary.copy(<<2>>, 4)

    write_piece_to_mnesia(src_file, 0, piece0)
    write_piece_to_mnesia(src_file, 1, piece1)

    metadata = %{info: %{name: "single_out.bin"}}
    data = %{file: src_file, num_pieces: 2}

    FileAssembler.assemble_file({metadata, data}, tmp_dir)

    output_path = Path.join(tmp_dir, "single_out.bin")
    assert File.read!(output_path) == piece0 <> piece1
  end

  test "assembles multi-file torrent across piece boundaries", %{tmp_dir: tmp_dir} do
    src_file = "multi_#{System.unique_integer([:positive])}.torrent"
    # 2 pieces of 6 bytes + 5 bytes = 11 bytes total
    # Split across: a.txt (4 bytes), sub/b.txt (5 bytes), empty.txt (0 bytes), c.txt (2 bytes)
    write_piece_to_mnesia(src_file, 0, "ABCDEF")
    write_piece_to_mnesia(src_file, 1, "GHIJK")

    metadata = %{
      info: %{
        name: "bundle",
        files: [
          %{length: 4, path: ["a.txt"]},
          %{length: 5, path: ["sub", "b.txt"]},
          %{length: 0, path: ["empty.txt"]},
          %{length: 2, path: ["c.txt"]}
        ]
      }
    }

    data = %{file: src_file, num_pieces: 2}

    FileAssembler.assemble_file({metadata, data}, tmp_dir)

    assert File.read!(Path.join([tmp_dir, "bundle", "a.txt"])) == "ABCD"
    assert File.read!(Path.join([tmp_dir, "bundle", "sub", "b.txt"])) == "EFGHI"
    assert File.read!(Path.join([tmp_dir, "bundle", "empty.txt"])) == ""
    assert File.read!(Path.join([tmp_dir, "bundle", "c.txt"])) == "JK"
  end

  defp write_piece_to_mnesia(src_file, index, buffer) do
    piece_id = :crypto.hash(:sha, buffer)

    {:atomic, :ok} =
      :mnesia.transaction(fn ->
        :mnesia.write(
          {@torrent_cache_name, piece_id, src_file, index, :complete, buffer}
        )
      end)
  end
end
