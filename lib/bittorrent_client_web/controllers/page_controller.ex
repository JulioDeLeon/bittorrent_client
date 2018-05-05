defmodule BittorrentClientWeb.PageController do
  use BittorrentClientWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
