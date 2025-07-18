defmodule Md.MixProject do
  use Mix.Project

  @app :md
  @version "0.11.0"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      xref: [exclude: []],
      description: description(),
      deps: deps(),
      aliases: aliases(),
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: [
        plt_file: {:no_warn, ".dialyzer/plts/dialyzer.plt"},
        plt_add_apps: [:floki],
        ignore_warnings: ".dialyzer/ignore.exs"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :inets],
      mod: {Md.Application, []}
    ]
  end

  def cli do
    [
      preferred_envs: [
        credo: :ci,
        dialyzer: :ci,
        tests: :test,
        "coveralls.json": :test,
        "coveralls.html": :test,
        "quality.ci": :ci
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:ci), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:xml_builder_ex, "~> 3.1"},
      {:unicode_guards, "~> 1.0"},
      {:floki, "~> 0.33", optional: Mix.env() != :dev},
      {:credo, "~> 1.0", only: :ci, runtime: false},
      {:excoveralls, "~> 0.14", only: :test, runtime: false},
      {:dialyxir, "~> 1.0", only: :ci, runtime: false},
      {:ex_doc, ">= 0.0.0", only: [:ci, :dev]},
      {:benchfella, "~> 0.3", only: :ci},
      {:earmark, "~> 1.4", only: :ci}
    ]
  end

  defp aliases do
    [
      quality: ["format", "credo --strict", "dialyzer"],
      tests: ["coveralls.html --trace"],
      "quality.ci": [
        "format --check-formatted",
        "credo --strict",
        "dialyzer --halt-exit-status"
      ]
    ]
  end

  defp description do
    """
    Custom extendable markdown parser.
    """
  end

  defp package do
    [
      name: @app,
      files: ~w|lib stuff/logo-48x48.png stuff/*.md mix.exs README.md|,
      maintainers: ["Aleksei Matiushkin"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/am-kantox/#{@app}",
        "Docs" => "https://hexdocs.pm/#{@app}"
      }
    ]
  end

  defp docs do
    [
      main: "Md",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/#{@app}",
      logo: "stuff/logo-48x48.png",
      source_url: "https://github.com/am-kantox/#{@app}",
      extras: ~w[README.md stuff/md-benefits.md],
      groups_for_modules: [
        # Md,
        # Md.Listener,
        # Md.Parser,
        # Md.Transforms,

        "Parser Internals": [
          Md.Parser.Default,
          Md.Parser.State,
          Md.Parser.Syntax,
          Md.Parser.Syntax.Void
        ],
        "Custom Transforms": [
          Md.Transforms.Anchor,
          Md.Transforms.Footnote,
          Md.Transforms.Soundcloud,
          Md.Transforms.TwitterHandle,
          Md.Transforms.Youtube
        ]
      ]
    ]
  end
end
