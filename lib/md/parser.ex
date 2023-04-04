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
    custom: [
      {"![", {MyApp.Parsers.Img, %{}}},
      ...
    ]
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

  @doc """
  The main function transforming the MD input to XML output.

  `options` are passed to `XmlBuilder.generate/2` as is, save for
    the special two special options, `parser:` and `walker:`.

  `parser:` option which is a module implementing `Parser` behaviour,
    is telling what parser to use for parsing.

  `walker:` option which might be a function of arity 2,
    or a tuple `{:pre | :post, fun}` where `fun` is a function of arity 1 or 2.

  If passed, `XmlBuilder.{pre,post}walk/{2,3}` is being called before generation.

  If `walker:` was not passed, or a `nil` value was returned from the accumulator,
    this function returns the binary `XML` as is, otherwise it returns a tuple
    `{XML, accumulator}` where `accumulator` is what has been returned from
    underlying calls to `XmlBuilder.traverse/4`.
  """
  @spec generate(binary() | L.state(), keyword()) :: binary() | {binary(), any()}
  def generate(input, options \\ [])

  def generate(input, options) when is_binary(input) and is_list(options) do
    {parser, options} = Keyword.pop(options, :parser, DefaultParser)
    input |> parser.parse() |> elem(1) |> generate(options)
  end

  def generate(%State{ast: ast}, options) when is_list(options) do
    {walker, options} = Keyword.pop(options, :walker)

    {ast, acc} =
      case walker do
        nil -> {ast, nil}
        fun when is_function(fun, 2) -> XmlBuilder.prewalk(ast, %{}, fun)
        {:pre, fun} when is_function(fun, 1) -> {XmlBuilder.prewalk(ast, fun), nil}
        {:post, fun} when is_function(fun, 1) -> {XmlBuilder.postwalk(ast, fun), nil}
        {:pre, fun} when is_function(fun, 2) -> XmlBuilder.prewalk(ast, %{}, fun)
        {:post, fun} when is_function(fun, 2) -> XmlBuilder.postwalk(ast, %{}, fun)
        {:pre, fun, acc} when is_function(fun, 2) -> XmlBuilder.prewalk(ast, acc, fun)
        {:post, fun, acc} when is_function(fun, 2) -> XmlBuilder.postwalk(ast, acc, fun)
      end

    options = Keyword.put_new(options, :format, *: :indent, pre: :none, code: :none)
    generated = XmlBuilder.generate(ast, options)

    if is_nil(acc), do: generated, else: {generated, acc}
  end

  def generate(%State{} = state, parser) when is_atom(parser),
    do: generate(state, parser: parser)

  @doc deprecated: "Use generate/2 instead passing `parser: parser` as option"
  @spec generate(binary() | L.state(), module(), keyword()) :: binary() | {binary(), any()}
  def generate(input, parser, options),
    do: generate(input, Keyword.put(options, :parser, parser))

  @doc false
  defmacro __using__(opts \\ []) do
    quote generated: true, location: :keep do
      require Md.Engine
      alias Md.Parser.State

      @before_compile Md.Engine

      if Keyword.get(unquote(opts), :dsl, false),
        do: require(Md.Parser.DSL)

      syntax = Module.get_attribute(__MODULE__, :syntax, %{})
      inplace_syntax = Keyword.get(unquote(opts), :syntax, %{})

      Module.register_attribute(__MODULE__, :syntax, accumulate: true)
      Module.put_attribute(__MODULE__, :syntax, Map.merge(syntax, inplace_syntax))

      @behaviour Md.Parser

      @impl Md.Parser
      def parse(input, state \\ %State{})

      def parse(input, state) do
          %State{ast: ast, path: []} = state = do_parse(input, state)
        {"", %State{state | ast: Enum.reverse(ast)}}
      end
    end
  end
end
