# BittorrentClient
**Bittorrent client written in Elixir for personal use**

[![Travis build](https://secure.travis-ci.org/JulioDeLeon/bittorrent_client.svg?branch=master
"Build Status")](https://travis-ci.org/JulioDeLeon/bittorrent_client)


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `bittorrent_client` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:bittorrent_client, "~> 0.1.0"}]
    end
    ```

  2. Ensure `bittorrent_client` is started before your application:

    ```elixir
    def application do
      [applications: [:bittorrent_client]]
    end
    ```

## REST Endpoints

```GET /api/v1/ping```: returns pong, meant for health checks

```GET /api/v1/{torrent id}/status```: Gets the current state of a torrent process which matches to given id

```PUT /api/v1/{torrent id}/connect```: Triggers torrent process to connect to it's respective tracker

```PUT /api/v1/{torrent id}/connect/async```: Triggers torrent process to connect to it's tracker asynchronously, providing no feedback of success or failure

```PUT /api/v1/{torrent id}/startTorrent```: Triggers torrent process to start sharing data, will fail if the torrent has not connected to tracker

```PUT /api/v1/{torrent id}/startTorrent/async```: Triggers torrent process to start sharing data asynchronously, will not provide feedback of failure

```POST /api/v1/addFile```: Opens a local torrent file and creates a torrent process from the information of the torrent file

```DELETE /api/v1/{torrent id}/remove```: Removes torrent process from client

```GET /api/v1/all```: Returns information of all torrents on the client

```DELETE /api/v1/remove/all```: Removes all torrents from the client

