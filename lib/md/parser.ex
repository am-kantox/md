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
  alias Md.Parser.State

  @typedoc """
  The type to be used in all the intermediate states of parsing.

  The first element iof the tuple is the continuation (not parsed yet input,)
  and the latter is the current state.
  """
  @type parsing_stage :: {binary(), L.state()}

  @doc """
  Takes a not parsed yet input and the state, returns the updated remainder and state.
  """
  @callback parse(binary(), L.state()) :: parsing_stage()

  # TODO analyze errors
  @spec generate(binary() | L.state(), keyword()) :: binary()
  def generate(input, parser \\ DefaultParser, options \\ [])

  def generate(input, parser, options) when is_binary(input),
    do: input |> parser.parse() |> elem(1) |> generate(parser, options)

  def generate(%State{ast: ast}, _parser, options),
    do: XmlBuilder.generate(ast, options)

  @doc false
  defmacro __using__(opts \\ []) do
    quote generated: true, location: :keep do
      require Md.Engine
      alias Md.Parser.State

      @before_compile Md.Engine

      if Keyword.get(unquote(opts), :dsl, false),
        do: require Md.Parser.DSL

      syntax = Module.get_attribute(__MODULE__, :syntax, %{})
      inplace_syntax = Keyword.get(unquote(opts), :syntax, %{})

      Module.register_attribute(__MODULE__, :syntax, accumulate: true)
      Module.put_attribute(__MODULE__, :syntax, Map.merge(syntax, inplace_syntax))

      @behaviour Md.Parser

      @impl Md.Parser
      def parse(input, state \\ %State{}) do
        %State{ast: ast, path: []} = state = do_parse(input, state)
        {"", %State{state | ast: Enum.reverse(ast)}}
      end
    end
  end
end
