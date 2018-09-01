defmodule BittorrentClientWeb.AdminController do
  use BittorrentClientWeb, :controller
  require Logger

  def status(conn, _args) do
    send_resp(conn, 200, "I do nothing")
  end

  def get_file_dest(conn, _args) do
    send_resp(conn, 200, "I do nothing")
  end

  def change_file_dest(conn, %{"directory" => dest}) do
    send_resp(conn, 200, "recieved #{dest}")
  end
end
