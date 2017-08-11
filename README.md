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

