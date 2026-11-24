defmodule BittorrentClient.Mixfile do
  use Mix.Project

  def project do
    [
      app: :bittorrent_client,
      version: "0.1.1",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: [
        bittorrent_client: [
          include_executables_for: [:unix]
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {BittorrentClient.Application, []},
      extra_applications: [:logger, :runtime_tools],
      included_applications: [:mnesia]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8"},
      {:phoenix_pubsub, "~> 2.4"},
      {:phoenix_view, "~> 2.0"},
      {:phoenix_html, "~> 4.4"},
      {:phoenix_html_helpers, "~> 1.0"},
      {:phoenix_live_reload, "~> 1.7", only: :dev},
      {:gettext, "~> 1.0"},
      {:bandit, "~> 1.15"},
      {:jason, "~> 1.4"},
      {:httpoison, "~> 3.0"},
      {:bento, "~> 1.0"},
      {:esbuild, "~> 0.10.1", runtime: Mix.env() == :dev},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["esbuild.install --if-missing"],
      "assets.build": ["esbuild bittorrent_client"],
      "assets.deploy": [
        "esbuild bittorrent_client --minify",
        "phx.digest"
      ]
    ]
  end
end
