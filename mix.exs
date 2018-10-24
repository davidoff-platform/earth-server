defmodule EarthServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :earth_server,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {EarthServer.Application, []},
      applications: [
        :edeliver
      ]
    ]
  end

  defp deps do
    [{:edeliver, ">= 1.6.0"}, {:distillery, "~> 2.0"}]
  end
end
