defmodule BittorrentClient.HTTPHandle.InMemoryImpl do
  @moduledoc """
  In memory implementation of the HTTPHandle behaviour for testing locally
  """
  @behaviour BittorrentClient.HTTPHandle
  require Logger
  @num_wanted Application.get_env(:bittorrent_client, :numwant)
  @arch_tracker_req_url "http://tracker.archlinux.org:6969/announce?compact=1&connected_peers=&downloaded=0&info_hash=%8B%DE%B5Pcm;R;-+;%D4%9D%7B%0F%C71%17l&left=631242752&next_piece_index=0&numwant=#{@num_wanted}&peer_id=-ET0001-aaaaaaaaaaaa&port=36562&uploaded=0"

  def get(@arch_tracker_req_url, _headers, _opts) do
    Logger.warn("Using #{__MODULE__} implementation for HTTPoison.get")

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

    {status, bento_body_resp} = Bento.encode(bento_body)

    case status do
      :ok ->
        {:ok,
         %HTTPoison.Response{
           body: bento_body_resp,
           headers: resp_headers,
           status_code: 200
         }}

      _ ->
        {:error,
         %HTTPoison.Error{
           __exception__: nil,
           id: nil,
           reason: "could not bento encode #{bento_body}"
         }}
    end
  end

  def get(url, headers, opts) do
    Logger.warn("Using #{__MODULE__} implementation for HTTPoison.get")

    {:error,
     %HTTPoison.Error{
       __exception__: nil,
       id: nil,
       reason:
         "Unreckognized URL #{inspect(url)} Headers #{inspect(headers)} Opts #{
           inspect(opts)
         } (Using InMemoryImpl)"
     }}
  end
end
