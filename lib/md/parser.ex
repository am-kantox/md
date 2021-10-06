defmodule Md.Parser do
  @moduledoc """
  Interface to implement for the custopm parsers.

  Custom parsers might be used in syntax declaration when the generic functionality
  is not enough.

  Let’s consider one needs a specific handling of links with titles.

  The generic engine does not support it, so one would need to implement a custom parser
  and instruct `Md.Parser` to use it with:

  ```elixir
  # config/prod.exs

  config :md, syntax: %{
    custom: %{
      {"![", MyApp.Parsers.Img},
      ...
    }
  }
  ```

  Once the original parser would meet the `"!["` binary, it’d call `MyApp.Parsers.Img.parse/2`.
  The latter must proceed until the tag is closed and return the remainder and the updated state
  as a tuple.
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

      @spec inspect(%Md.Parser.State{}, Inspect.Opts.t()) ::
              :doc_line
              | :doc_nil
              | binary
              | {:doc_collapse, pos_integer}
              | {:doc_force, any}
              | {:doc_break | :doc_color | :doc_cons | :doc_fits | :doc_group | :doc_string, any,
                 any}
              | {:doc_nest, any, :cursor | :reset | non_neg_integer, :always | :break}
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

  @typedoc """
  The type to be used in all the intermediate states of parsing.

  The first element iof the tuple is the continuation (not parsed yet input,)
  and the latter is the current state.
  """
  @type parsing_stage :: {binary(), L.state()}

  @doc """
  Takes a not parsed yet input and the state, returns the updated remainder and state.
  """
  @callback parse(binary(), module()) :: parsing_stage()

  # TODO analyze errors
  @spec generate(binary() | L.state(), keyword()) :: binary()
  def generate(input, options \\ [])

  def generate(input, options) when is_binary(input),
    do: input |> DefaultParser.parse() |> elem(1) |> generate(options)

  def generate(%State{ast: ast}, options),
    do: XmlBuilder.generate(ast, options)
end
