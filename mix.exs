defmodule ReinterpretCast.MixProject do
  use Mix.Project

  def project do
    [
      app: :reinterpret_cast,
      version: "0.1.0",
      elixir: "~> 1.13",
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
      {:ex_doc, "~> 0.3", only: :dev, runtime: false}
    ]
  end
end
