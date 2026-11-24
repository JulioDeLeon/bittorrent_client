defmodule BittorrentClient.HTTPHandle.InMemoryImpl do
  @moduledoc """
  In memory implementation of the HTTPHandle behaviour for testing locally
  """
  @behaviour BittorrentClient.HTTPHandle
  require Logger
  alias Bento.Encoder, as: BenEncoder
  @num_wanted Application.compile_env(:bittorrent_client, :numwant)
  @arch_tracker_base "http://tracker.archlinux.org:6969/announce"
  @arch_tracker_query %{
    "compact" => "1",
    "downloaded" => "0",
    "info_hash" =>
      <<139, 222, 181, 80, 99, 109, 59, 82, 59, 45, 32, 59, 212, 157, 123, 15,
        199, 49, 23, 108>>,
    "left" => "631242752",
    "num_pieces" => "1204",
    "numwant" => "#{@num_wanted}",
    "peer_id" => "-ET0001-aaaaaaaaaaaa",
    "port" => "36562",
    "uploaded" => "0"
  }

  @impl true
  def get(url, headers, opts) do
    Logger.warning("Using #{__MODULE__} implementation for HTTPoison.get")
    uri = URI.parse(url)
    base = "#{uri.scheme}://#{uri.host}:#{uri.port}#{uri.path}"

    if base == @arch_tracker_base and
         URI.decode_query(uri.query || "") == @arch_tracker_query do
      # simulating response from Arch Linux servers
      resp_headers = [
        {"Server", "mimosa"},
        {"Connection", "Close"},
        {"Content-Length", "518"},
        {"Content-Type", "text/plain"}
      ]

      bento_body = %{
        "interval" => 900,
        "peers" => <<79, 95, 107, 22, 192, 180>>,
        "peers6" => ""
      }

      bento_body_resp =
        bento_body
        |> BenEncoder.encode()
        |> IO.iodata_to_binary()

      {:ok,
       %HTTPoison.Response{
         body: bento_body_resp,
         headers: resp_headers,
         status_code: 200
       }}
    else
      {:error,
       %HTTPoison.Error{
         __exception__: nil,
         id: nil,
         reason:
           "Unreckognized URL #{inspect(url)} Headers #{inspect(headers)} Opts #{inspect(opts)} (Using InMemoryImpl)"
       }}
    end
  end
end
