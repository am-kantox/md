defmodule Md.Parser do
  @default_syntax [
    outer: :p,
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

  alias Md.Listener, as: L

  defmodule State do
    @moduledoc """
    The internal state of the parser.
    """
    defstruct path: [], ast: [], listener: nil, bag: []
  end

  defmodule DebugListener do
    @moduledoc false
    require Logger

    @behaviour L

    @impl L
    def element(context, state) do
      Logger.debug("Context: " <> inspect(context) <> ". State: " <> inspect(state))
    end
  end

  @syntax :md
          |> Application.compile_env(:syntax, @default_syntax)
          |> Enum.map(fn
            {k, v} when is_list(v) ->
              {k, Enum.sort_by(v, &(-String.length(elem(&1, 0))))}

            {k, v} ->
              {k, v}
          end)

  @compile {:inline, syntax: 0}
  def syntax, do: @syntax

  @spec parse(binary(), module()) :: L.state()
  def parse(input, listener \\ DebugListener) do
    %State{ast: ast, path: []} = state = do_parse(input, %State{listener: listener}, :linefeed)
    %State{state | ast: Enum.reverse(ast)}
  end

  # TODO analyze errors
  @spec generate(binary() | L.state(), keyword()) :: binary()
  def generate(input, options \\ [])

  def generate(input, options) when is_binary(input),
    do: input |> parse() |> generate(options)

  def generate(%State{ast: ast}, options),
    do: XmlBuilder.generate(ast, options)

  # defmacrop empty, do: quote(do: %State{path: []} = var!(state))
  defmacrop state, do: quote(do: %State{} = var!(state))

  @type parse_mode :: :md | :raw | :linefeed
  @spec do_parse(binary(), L.state(), parse_mode()) :: L.state()
  defp do_parse(input, state, mode)

  # → :linefeed
  defp do_parse(<<?\n, rest::binary>>, state(), :md) do
    state = listener(:linefeed, state)
    do_parse(rest, push_char(?\s, state, :md), :linefeed)
  end

  ## linefeed mode
  defp do_parse(<<?\s, rest::binary>>, state(), :linefeed) do
    state = listener(:whitespace, state)
    do_parse(rest, state, :linefeed)
  end

  defp do_parse(<<?\n, rest::binary>>, state(), :linefeed) do
    state = listener(:break, state)
    do_parse(rest, rewind_state(state), :linefeed)
  end

  Enum.each(@syntax[:flush], fn {md, properties} ->
    tag = properties[:tag]
    attrs = Macro.escape(properties[:attributes])

    defp do_parse(<<unquote(md), rest::binary>>, state(), :linefeed) do
      state = listener({:tag, unquote(md), nil}, state)
      state = rewind_state(state)

      do_parse(
        rest,
        %State{state | path: [{unquote(tag), unquote(attrs), []} | state.path]},
        :linefeed
      )
    end
  end)

  ## escaped symbol
  defp do_parse(<<?\\, x::utf8, rest::binary>>, state(), mode) when mode != :raw do
    state = listener({:esc, <<x::utf8>>}, state)
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
      state = listener({:tag, unquote(md), false}, state)
      do_parse(rest, to_ast(state), :md)
    end

    defp do_parse(<<unquote(md), rest::binary>>, state(), mode) when mode != :raw do
      state = listener({:tag, unquote(md), true}, state)

      do_parse(
        rest,
        %State{state | path: [{unquote(tag), unquote(attrs), [""]} | state.path]},
        :md
      )
    end
  end)

  ## plain text handlers

  defp do_parse(<<x::utf8, rest::binary>>, state(), mode) do
    state = listener({:tag, <<x::utf8>>, true}, state)
    do_parse(rest, push_char(x, state, mode), :md)
  end

  defp do_parse("", state(), _) do
    state = listener(:end, state)
    rewind_state(state)
  end

  ## helpers
  @spec listener(L.context(), L.state()) :: L.state()
  def listener(context, state) do
    case state.listener.element(context, state) do
      :ok -> state
      {:update, state} -> state
    end
  end

  @spec rewind_state(L.state()) :: L.state()
  defp rewind_state(state) do
    Enum.reduce(state.path, state, fn _, acc -> to_ast(acc) end)
  end

  @spec push_char(pos_integer(), L.state(), parse_mode()) :: L.state()
  defp push_char(x, state, mode) do
    path =
      case {mode, state.path} do
        {:linefeed, path} ->
          [{syntax()[:outer], [], [<<x::utf8>>]} | path]

        {_, [{elem, attrs, [txt | branch]} | rest]} when is_binary(txt) ->
          [{elem, attrs, [txt <> <<x::utf8>> | branch]} | rest]

        {_, [{elem, attrs, branch} | rest]} ->
          [{elem, attrs, [<<x::utf8>> | branch]} | rest]
      end

    %State{state | path: path}
  end

  @spec to_ast(L.state()) :: L.state()
  defp to_ast(%State{path: [], ast: _} = state), do: state

  defp to_ast(%State{path: [last], ast: ast} = state),
    do: %State{state | path: [], ast: [reverse(last) | ast]}

  defp to_ast(%State{path: [last, {elem, attrs, branch} | rest]} = state),
    do: %State{state | path: [{elem, attrs, [reverse(last) | branch]} | rest]}

  @spec reverse(L.trace()) :: L.trace()
  defp reverse({elem, attrs, branch}) when is_list(branch),
    do: {elem, attrs, Enum.reverse(branch)}

  defp reverse(any), do: any
end
