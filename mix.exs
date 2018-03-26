defmodule BittorrentClient.Mixfile do
  use Mix.Project

  def project do
    [
      app: :bittorrent_client,
      version: "0.1.1",
      elixir: "~> 1.6",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        plt_add_deps: :transitive
      ]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [
      applications: [
        :logger,
        :cowboy,
        :plug,
        :gproc,
        :httpoison
      ],
      env: [
        key_file: [],
        cert_file: [],
        peer_id: [],
        compact: [],
        port: [],
        no_peer_id: [],
        ip: [],
        numwant: [],
        key: []
      ],
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
      # http library
      {:cowboy, "1.0.0"},
      # http wrapper for cowboy
      {:plug, "~> 1.0"},
      # framework for http library
      {:httpoison, "~> 0.11.1", runtime: true},
      # mocking library
      {:meck, "~> 0.8.2", only: :test},
      # bencoder...
      {:bento, "~> 0.9.2"},
      {:hackney, "~> 1.6", override: true},
      # global process registry
      {:gproc, "~> 0.5"},
      # code quality tool
      {:credo, "~> 0.9.0-rc1", only: :dev},
      {:dogma, "~> 0.1", only: :dev},
      {:dialyxir, "~> 0.5", only: [:dev]},
      {:earmark, "~> 1.2.2", only: :dev},
      {:ex_doc, "~> 0.16", only: :dev}
    ]
  end
end
