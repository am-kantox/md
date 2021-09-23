defmodule Md.Parser do
  require Logger

  @default_syntax [
    flush: [
      {"---", %{tag: :hr}}
    ],
    magnet: [
      {"¡", %{tag: :abbr}}
    ],
    braces: [
      {"*", %{tag: :b}},
      {"_", %{tag: :it}},
      {"**", %{tag: :strong, attributes: %{class: "red"}}},
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

  @spec parse(binary()) :: State.t()
  def parse(input) do
    %State{ast: ast, path: []} = do_parse(input, %State{}, :linefeed)
    %State{ast: Enum.reverse(ast), path: []}
  end

  # TODO analyze errors
  @spec generate(binary()) :: binary()
  def generate(input) do
    with %State{ast: ast} <- parse(input), do: XmlBuilder.generate(ast)
  end

  # defmacrop empty, do: quote(do: %State{path: []} = var!(state))
  defmacrop state, do: quote(do: %State{} = var!(state))

  @type parse_mode :: :md | :raw | :linefeed
  @spec do_parse(binary(), State.t(), parse_mode()) :: State.t()
  defp do_parse(input, state, mode)

  # → :linefeed
  defp do_parse(<<?\n, rest::binary>>, state(), :md) do
    Logger.debug("Linefeed. State: " <> inspect(state))
    do_parse(rest, push_char(?\s, state, :md), :linefeed)
  end

  ## linefeed mode
  defp do_parse(<<?\s, rest::binary>>, state(), :linefeed) do
    Logger.debug("Squeezing whitespace. State: " <> inspect(state))
    do_parse(rest, state, :linefeed)
  end

  defp do_parse(<<?\n, rest::binary>>, state(), :linefeed) do
    Logger.debug("Skipping whitespace. State: " <> inspect(state))
    do_parse(rest, rewind_state(state), :linefeed)
  end

  Enum.each(@syntax[:flush], fn {md, properties} ->
    tag = properties[:tag]
    attrs = Macro.escape(properties[:attributes])

    defp do_parse(<<unquote(md), rest::binary>>, state(), :linefeed) do
      Logger.debug("Flushing #{unquote(md)}. State: " <> inspect(state))
      state = rewind_state(state)
      Logger.debug("Flushing #{unquote(md)}. State: " <> inspect(state))

      do_parse(
        rest,
        %State{state | path: [{unquote(tag), unquote(attrs), []} | state.path]},
        :linefeed
      )
    end
  end)

  ## escaped symbol
  defp do_parse(<<?\\, x::utf8, rest::binary>>, state(), mode) when mode != :raw do
    Logger.debug("Escaped entity ‹#{<<x::utf8>>}›")
    do_parse(<<x::utf8, rest::binary>>, state, :raw)
  end

  Enum.each(@syntax[:braces], fn {md, properties} ->
    tag = properties[:tag]
    attrs = Macro.escape(properties[:attributes])

    defp do_parse(
           <<unquote(md), rest::binary>>,
           %State{path: [{unquote(tag), _, _} | _]} = state,
           mode
         )
         when mode != :raw do
      Logger.debug("Closing #{unquote(md)}. State: " <> inspect(state))
      do_parse(rest, to_ast(state), :md)
    end

    defp do_parse(<<unquote(md), rest::binary>>, state(), mode) when mode != :raw do
      Logger.debug("Opening #{unquote(md)}. State: " <> inspect(state))

      do_parse(
        rest,
        %State{state | path: [{unquote(tag), unquote(attrs), [""]} | state.path]},
        :md
      )
    end
  end)

  ## plain text handlers

  defp do_parse(<<x::utf8, rest::binary>>, state(), mode) do
    Logger.debug("Pushing #{<<x::utf8>>}. State: " <> inspect(state))
    do_parse(rest, push_char(x, state, mode), :md)
  end

  defp do_parse("", state(), _) do
    Logger.debug("Finalizing. State: " <> inspect(state))
    rewind_state(state)
  end

  ## helpers
  @spec rewind_state(State.t()) :: State.t()
  defp rewind_state(state) do
    Enum.reduce(state.path, state, fn _, acc -> to_ast(acc) end)
  end

  @spec push_char(pos_integer(), State.t(), parse_mode()) :: State.t()
  defp push_char(x, state, mode) do
    path =
      case {mode, state.path} do
        {:linefeed, path} ->
          [{@outer, [], [<<x::utf8>>]} | path]

        {_, [{elem, attrs, [txt | branch]} | rest]} when is_binary(txt) ->
          [{elem, attrs, [txt <> <<x::utf8>> | branch]} | rest]

        {_, [{elem, attrs, branch} | rest]} ->
          [{elem, attrs, [<<x::utf8>> | branch]} | rest]
      end

    %State{state | path: path}
  end

  @spec to_ast(State.t()) :: State.t()
  defp to_ast(%State{path: [], ast: _} = state), do: state

  defp to_ast(%State{path: [last], ast: ast} = state),
    do: %State{state | path: [], ast: [reverse(last) | ast]}

  defp to_ast(%State{path: [last, {elem, attrs, branch} | rest]} = state),
    do: %State{state | path: [{elem, attrs, [reverse(last) | branch]} | rest]}

  @spec reverse(State.trace()) :: State.trace()
  defp reverse({elem, attrs, branch}) when is_list(branch),
    do: {elem, attrs, Enum.reverse(branch)}

  defp reverse(any), do: any
end
