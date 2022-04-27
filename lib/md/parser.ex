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
  alias Md.Parser.State
  alias Md.Parser.Default, as: DefaultParser

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
  def generate(input, options \\ [])

  def generate(input, options) when is_binary(input),
    do: input |> DefaultParser.parse() |> elem(1) |> generate(options)

  def generate(%State{ast: ast}, options),
    do: XmlBuilder.generate(ast, options)
end
