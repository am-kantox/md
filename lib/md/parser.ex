defmodule Md.Parser do
  @moduledoc """

  """
  alias Md.Listener, as: L
  alias Md.Parser.Default, as: DefaultParser

  defmodule State do
    @moduledoc """
    The internal state of the parser.
    """
    defstruct path: [], ast: [], mode: [:idle], listener: nil, bag: %{indent: [], stock: []}

    defimpl Inspect do
      @moduledoc false
      import Inspect.Algebra

      def inspect(
            %State{path: path, ast: ast, mode: mode, bag: %{indent: indent, stock: stock}},
            opts
          ) do
        inner = [
          path: path,
          ast: ast,
          internals: [mode: mode, indent: indent, stock: stock]
        ]

        concat(["#Md<", to_doc(inner, opts), ">"])
      end
    end
  end

  @callback parse(binary(), module()) :: L.state()

  # TODO analyze errors
  @spec generate(binary() | L.state(), keyword()) :: binary()
  def generate(input, options \\ [])

  def generate(input, options) when is_binary(input),
    do: input |> DefaultParser.parse() |> generate(options)

  def generate(%State{ast: ast}, options),
    do: XmlBuilder.generate(ast, options)
end
