defmodule BittorrentClient.Mixfile do
  use Mix.Project

  def project do
    [app: :bittorrent_client,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [
      applications: [:logger, :cowboy, :plug, :gproc, :httpoison],
      env: [key_file: [],
            cert_file: [],
            peer_id: [],
            compact: [],
            port: [],
            no_peer_id: [],
            ip: [],
            numwant: [],
            key: [],
            trackerid: []],
      mod: {BittorrentClient, []}
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:cowboy, "1.0.0"},                      # http library
      {:plug, "~> 1.0"},                       # http wrapper for cowboy
      {:httpoison, "~> 0.11.1", runtime: true},                # framework for http library
      {:meck, "~> 0.8.2", only: :test},        # mocking library
      {:bento, "~> 0.9.2"},                    # bencoder...
      {:hackney, "~> 1.6", override: true},
      {:gproc, "~> 0.5"},					             # global process registry
      {:credo, "~> 0.7", only: [:dev, :test]}, # code quality tool
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:rustler, "~> 0.9.0"}
    ]
  end
end
