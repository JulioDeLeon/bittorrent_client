defmodule BittorrentClient.HTTPHandle.InMemoryImpl do
  @moduledoc """
  In memory implementation of the HTTPHandle behaviour for testing locally
  """
  @behaviour BittorrentClient.HTTPHandle
  require Logger
  @arch_tracker_req_url "http://tracker.archlinux.org:6969/announce?compact=1&connected_peers=&downloaded=0&info_hash=-;=e%B3i%BAQ%92%92%DD%8C%E4%20%AF%E9Q%20%DF%1E&left=547356672&next_piece_index=0&numwant=80&peer_id=-ET0001-aaaaaaaaaaaa&port=36562&uploaded=0"
  def get(@arch_tracker_req_url, _headers, _opts) do
    Logger.warn(
      
      "Using #{__MODULE__} implementation for HTTPoison.get"
    )

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

  def get(_url, _headers, []) do
    Logger.warn(
      
      "Using #{__MODULE__} implementation for HTTPoison.get"
    )

    {:error,
     %HTTPoison.Error{__exception__: nil, id: nil, reason: "Empty opts?"}}
  end
end
