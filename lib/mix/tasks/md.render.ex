defmodule Mix.Tasks.Md.Render do
  @shortdoc "Renders a markdown file to HTML"

  @moduledoc """
  Renders a markdown file (or standard input) to HTML.

      $ mix md.render README.md
      $ mix md.render README.md --output README.html
      $ cat README.md | mix md.render --parser MyApp.Parser

  ## Options

    * `--output`, `-o` -- write to a file instead of standard output.
    * `--parser`, `-p` -- the parser module to use. Default: `Md.Parser.Default`.
    * `--format` -- `none` (default) or `indent`.
    * `--sanitize` -- run the result through `Md.Listener.Sanitizer`.

  With no file argument the input is read from standard input.
  """

  use Mix.Task

  @switches [
    output: :string,
    parser: :string,
    format: :string,
    sanitize: :boolean
  ]

  @aliases [o: :output, p: :parser]

  @impl Mix.Task
  def run(argv) do
    {options, args} = OptionParser.parse!(argv, strict: @switches, aliases: @aliases)

    html =
      args
      |> read_input()
      |> render(options)

    case Keyword.get(options, :output) do
      nil -> Mix.shell().info(html)
      path -> File.write!(path, html)
    end
  end

  @spec read_input([String.t()]) :: String.t()
  defp read_input([]), do: IO.read(:stdio, :eof)
  defp read_input([path]), do: File.read!(path)

  defp read_input(paths) do
    Mix.raise("expected at most one input file, got: #{Enum.join(paths, ", ")}")
  end

  @spec render(String.t(), keyword()) :: String.t()
  defp render(input, options) do
    parser =
      options
      |> Keyword.get(:parser, "Md.Parser.Default")
      |> String.split(".")
      |> Module.concat()

    format =
      case Keyword.get(options, :format, "none") do
        "none" -> :none
        "indent" -> :indent
        other -> Mix.raise("unknown --format #{inspect(other)}, expected none or indent")
      end

    state = %Md.Parser.State{type: parser}
    state = if options[:sanitize], do: %{state | listener: Md.Listener.Sanitizer}, else: state

    input
    |> Md.parse(state)
    |> Md.generate(format: format)
    |> to_string()
  end
end
