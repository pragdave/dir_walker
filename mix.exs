defmodule DirWalker.Mixfile do
  use Mix.Project

  @moduledoc """
  DirWalker lazily traverses one or more directory trees, depth first,
  returning successive file names. Provides both a `next()` and
  a Stream-based API.

  Directory names may optionally be returned. The File.Stat structure
  associated with the file name may also optionally be returned.
  """

  def project do
    [
      app:         :dir_walker,
      version:     "0.0.8",
      elixir:      ">= 1.5.0",
      deps:        deps(),
      description: @moduledoc,
      package:     package()
    ]
  end

  def application do
    [applications: [:logger]]
  end

  defp package do
    [
      files: [
        "lib",
        "mix.exs",
        "README.md"
      ],
      contributors: [
        "Dave Thomas     <dave@pragdave.me>",
        "Booker C. Bense <bbense@gmail.com>"
      ],
      licenses: [
        "Same as Elixir"
      ],
      links: %{
        "GitHub" => "https://github.com/pragdave/dir_walker"
      },
    ]
  end

  def deps do
    [
      {:ex_doc,  "~> 0.5", only: :dev},
    ]
  end
end
