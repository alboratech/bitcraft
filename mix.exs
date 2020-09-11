defmodule Bitcraft.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :bitcraft,
      version: @version,
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),

      # Docs
      name: "Bitcraft",
      docs: docs(),

      # Testing
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],

      # Dialyzer
      dialyzer: dialyzer(),

      # Hex
      package: package(),
      description: """
      Toolkit and DSL for encoding/decoding bitstring and binary protocols.
      """
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application, do: []

  defp deps do
    [
      # Test
      {:excoveralls, "~> 0.13", only: :test},

      # Code Analysis
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.4", only: [:dev, :test]},

      # Docs
      {:ex_doc, "~> 0.22", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: :bitcraft,
      maintainers: ["Carlos Bolanos"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/cabol/bitcraft"}
    ]
  end

  defp docs do
    [
      main: "Bitcraft",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/bitcraft",
      source_url: "https://github.com/cabol/bitcraft"
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      flags: [
        :unmatched_returns,
        :error_handling,
        :race_conditions,
        :no_opaque,
        :unknown,
        :no_return
      ]
    ]
  end
end
