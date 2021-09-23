defmodule Md.Parser do
  require Logger

  @default_syntax [
    full_stop: [
      # "\n\n"
    ],
    magnet: [
      {"¡", %{tag: :abbr}}
    ],
    braces: [
      {"*", %{tag: :b}},
      {"_", %{tag: :it}},
      {"**", %{tag: :strong}},
      {"__", %{tag: :em}},
      {"~", %{tag: :s}},
      {"~~", %{tag: :del}}
    ]
  ]

  defmodule State do
    @moduledoc false
    @type element :: atom()
    @type attributes :: nil | %{required(element()) => any()}
    @type leaf :: binary()
    @type branch :: {element(), attributes(), [leaf() | branch()]}
    @type trace :: branch()

    @type t :: %State{path: [trace()], ast: [branch()]}

    defstruct path: [], ast: []
  end

  @outer :p

  @syntax :md
          |> Application.compile_env(:syntax, @default_syntax)
          |> Enum.map(fn {k, v} ->
            {k, Enum.sort_by(v, &(-String.length(elem(&1, 0))))}
          end)

  def syntax, do: @syntax

  def parse(input), do: do_parse(input, %State{})

  def generate(input), do: input |> parse() |> XmlBuilder.generate()

  defmacrop empty, do: quote(do: %State{path: []} = var!(state))
  defmacrop state, do: quote(do: %State{} = var!(state))

  defp do_parse(input, state, format \\ true)

  ## redundant spaces
  defp do_parse(<<?\s, rest::binary>>, empty(), _) do
    Logger.debug("Skipping whitespace with empty state")
    do_parse(rest, state)
  end

  ## escaped symbol
  defp do_parse(<<?\\, x::utf8, rest::binary>>, state(), true) do
    Logger.debug("Escaped entity ‹#{<<x::utf8>>}›")
    do_parse(<<x::utf8, rest::binary>>, state, false)
  end

  Enum.each(@syntax[:braces], fn {md, properties} ->
    tag = properties[:tag]

    defp do_parse(
           <<unquote(md), rest::binary>>,
           %State{path: [{unquote(tag), _, _} | _]} = state,
           true
         ) do
      Logger.debug("Closing #{unquote(md)}. State: " <> inspect(state))
      do_parse(rest, to_ast(state), true)
    end

    defp do_parse(<<unquote(md), rest::binary>>, state(), true) do
      Logger.debug("Opening #{unquote(md)}. State: " <> inspect(state))
      do_parse(rest, %State{state | path: [{unquote(tag), %{}, [""]} | state.path]}, true)
    end
  end)

  ## plain text handlers

  defp do_parse(<<x::utf8, rest::binary>>, state(), _format) do
    Logger.debug("Pushing #{<<x::utf8>>}. State: " <> inspect(state))

    path =
      case state.path do
        [] ->
          [{@outer, [], [<<x::utf8>>]}]

        [{elem, attrs, [txt | branch]} | rest] when is_binary(txt) ->
          [{elem, attrs, [txt <> <<x::utf8>> | branch]} | rest]

        [{elem, attrs, branch} | rest] ->
          [{elem, attrs, [<<x::utf8>> | branch]} | rest]
      end

    do_parse(rest, %State{state | path: path}, true)
  end

  defp do_parse("", state(), _) do
    Logger.debug("Finalizing. State: " <> inspect(state))

    Enum.reduce(state.path, state, fn _, acc -> to_ast(acc) end)
  end

  ## helpers
  defp to_ast(%State{path: [], ast: _} = state), do: state

  defp to_ast(%State{path: [last], ast: ast} = state),
    do: %State{state | path: [], ast: [reverse(last) | ast]}

  defp to_ast(%State{path: [last, {elem, attrs, branch} | rest]} = state),
    do: %State{state | path: [{elem, attrs, [reverse(last) | branch]} | rest]}

  defp reverse({elem, attrs, branch}) when is_list(branch),
    do: {elem, attrs, Enum.reverse(branch)}

  defp reverse(any), do: any
end
