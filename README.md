# BittorrentClient [![Travis build](https://secure.travis-ci.org/JulioDeLeon/bittorrent_client.svg?branch=master "Build Status")](https://travis-ci.org/JulioDeLeon/bittorrent_client)

BittorrentClient is a simple bittorrent client being written for personal use. This project is a very beta phase of 
development and is missing some key features before it can be used for daily use. 

## Start Server locally

  * Install dependencies with `mix deps.get`
  * Install Node.js dependencies with `cd assets && npm install`
  * Start Phoenix endpoint with `mix phx.server`
  ** to start with repl `iex -S phx.server`

## Using BittorrentClient

BittorrentClient currently is a RESTful service an API to interact with:

### Admin API (BETA)
API | Description
--- | -----------
`GET /` | server status
`PUT /fileDestination` | change file destination
`GET /fileDestination` | get current file destination

### Torrent API (prefixed `/api/v1`)
API | Description
----| -----------
`GET /torrent/<id>/status` | retrieve status of a torrent by ID
`GET /torrent/<id>/info` | retrieve information about a given torrent by ID
`PUT /torrent/<id>/connect` | connect a torrent to it's tracker by ID
`PUT /torrent/<id>/connect/async` | connect a torrent to it's tracker by ID, call being asynchronous 
`PUT /torrent/<ID>/startTorrent` | begins the download process of torrent process, will fail if not connected to tracker
`PUT /torrent/<ID>/startTorrent/async` | will attempt to start torrent, does not respond with failure or success
`POST /torrent/addFile` | given a local file path, will add a torrent to BittorentClient
`DELETE /torrent/<id>` | removes torrent from BittorrentClient 
`GET /torrent` | retrieves info on all torrents in BittorrentClient
`delete /torrent/removeAll` | deletes all torrents in BittorrentClient

*note that this client does not support magnet link yet
