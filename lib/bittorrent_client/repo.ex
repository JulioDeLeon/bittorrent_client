defmodule BittorrentClient.Repo do

  @doc """
  Dynamically loads the repository url from the
  DATABASE_URL environment variable.
  """
  def init(_, _opts) do
    {:ok, {}}
  end
end
