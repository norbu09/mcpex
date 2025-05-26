defmodule Mcpex.MixProject do
  use Mix.Project

  def project do
    [
      app: :mcpex,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Mcpex.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
    defp deps do
    [
      # JSON handling
      {:jason, "~> 1.4"},

      # Schema validation
      {:ex_json_schema, "~> 0.10"},

      # HTTP server and transport
      {:plug, "~> 1.17"},
      {:bandit, "~> 1.0"},

      # Development and testing
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:bypass, "~> 2.1", only: :test}
    ]
  end
end
