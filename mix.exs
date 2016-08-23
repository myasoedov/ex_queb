defmodule ExQueb.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_queb,
     version: "0.2.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     docs: [extras: ["README.md"], main: "ExQueb"],
     package: package,
     name: "ExQueb",
     deps: deps,
     description: """
     Ecto Filter Query Builder
     """
   ]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:ecto, "~> 2.0"},
      {:ex_doc, "== 0.11.5", only: :dev},
      {:earmark, "== 0.2.1", only: :dev, override: true},
    ]
  end

  defp package do
    [ maintainers: ["Stephen Pallen"],
      licenses: ["MIT"],
      links: %{ "Github" => "https://github.com/E-MetroTel/ex_queb" },
      files: ~w(lib README.md mix.exs LICENSE)]
  end
end
