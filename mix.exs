defmodule CacheBench.MixProject do
  use Mix.Project

  def project do
    [
      app: :cache_benchmark,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:benchee, "~> 1.3", only: :dev}
    ]
  end
end
