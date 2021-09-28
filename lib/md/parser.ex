defmodule Md.Parser do
  @default_syntax [
    outer: :p,
    flush: [
      {"---", %{tag: :hr}}
    ],
    magnet: [
      {"¡", %{tag: :abbr}}
    ],
    paragraph: [
      {"#", %{tag: :h1}},
      {"##", %{tag: :h2}},
      {"###", %{tag: :h3}},
      {"####", %{tag: :h4}},
      {"#####", %{tag: :h5}},
      {"######", %{tag: :h6}},
      # nested
      {">", %{tag: :blockquote}}
    ],
    list: [
      {"-", %{tag: :li, outer: :ul}}
    ],
    brace: [
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
    defstruct path: [], ast: [], listener: nil, bag: [], indent: 0
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
  def parse(input, listener \\ L.Debug) do
    %State{ast: ast, path: []} = state = do_parse(input, %State{listener: listener}, :none)
    %State{state | ast: Enum.reverse(ast)}
  end

  # TODO analyze errors
  @spec generate(binary() | L.state(), keyword()) :: binary()
  def generate(input, options \\ [])

  def generate(input, options) when is_binary(input),
    do: input |> parse() |> generate(options)

  def generate(%State{ast: ast}, options),
    do: XmlBuilder.generate(ast, options)

  defmacrop initial, do: quote(do: %State{path: [], ast: []} = var!(state))
  defmacrop empty, do: quote(do: %State{path: []} = var!(state))
  defmacrop state, do: quote(do: %State{} = var!(state))

  @type parse_mode ::
          :none
          | :md
          | :raw
          | {:linefeed, non_neg_integer()}
          | {:nested, L.element(), non_neg_integer()}
          | {:inner, L.element(), non_neg_integer()}
  @spec do_parse(binary(), L.state(), parse_mode()) :: L.state()
  defp do_parse(input, state, mode)

  # :start
  defp do_parse(input, initial(), :none) do
    state = listener(:start, state)
    do_parse(input, state, {:linefeed, 0})
  end

  # → :linefeed
  defp do_parse(<<?\n, rest::binary>>, state(), :md) do
    state = listener(:linefeed, state)
    do_parse(rest, push_char(?\s, state, :md), {:linefeed, 0})
  end

  ## linefeed mode
  defp do_parse(<<?\s, rest::binary>>, state(), {:linefeed, pos}) do
    state = listener(:whitespace, state)
    do_parse(rest, state, {:linefeed, pos + 1})
  end

  defp do_parse(<<?\s, rest::binary>>, state(), {:nested, _, _} = nested) do
    state = listener(:whitespace, state)
    do_parse(rest, state, nested)
  end

  defp do_parse(<<?\n, rest::binary>>, state(), {:linefeed, _}) do
    state = listener(:break, state)
    do_parse(rest, rewind_state(state), {:linefeed, 0})
  end

  Enum.each(@syntax[:flush], fn {md, properties} ->
    tag = properties[:tag]
    attrs = Macro.escape(properties[:attributes])

    defp do_parse(<<unquote(md), rest::binary>>, state(), {:linefeed, _}) do
      state = listener({:tag, {unquote(md), unquote(tag)}, nil}, state)
      state = rewind_state(state)

      do_parse(
        rest,
        %State{state | path: [{unquote(tag), unquote(attrs), []} | state.path]},
        {:linefeed, 0}
      )
    end
  end)

  ## escaped symbol
  defp do_parse(<<?\\, x::utf8, rest::binary>>, state(), mode) when mode != :raw do
    state = listener({:esc, <<x::utf8>>}, state)
    do_parse(<<x::utf8, rest::binary>>, state, :raw)
  end

  Enum.each(@syntax[:paragraph], fn {md, properties} ->
    tag = properties[:tag]
    attrs = Macro.escape(properties[:attributes])

    defp do_parse(<<unquote(md), rest::binary>>, empty(), _) do
      state = listener({:tag, {unquote(md), unquote(tag)}, true}, state)

      do_parse(
        rest,
        %State{state | path: [{unquote(tag), unquote(attrs), []}]},
        {:nested, unquote(tag), 1}
      )
    end

    defp do_parse(
           <<unquote(md), rest::binary>>,
           %State{path: [{unquote(tag), _, _} | _]} = state,
           mode
         )
         when mode != :raw do
      current_level = level(state, unquote(tag))

      case mode do
        {:linefeed, _} ->
          do_parse(rest, state, {:nested, unquote(tag), 1})

        :md ->
          do_parse(rest, push_char(unquote(md), state, :md), :md)

        {:nested, unquote(tag), level} when level < current_level ->
          do_parse(rest, state, {:nested, unquote(tag), level + 1})

        {:nested, unquote(tag), level} ->
          state = listener({:tag, {unquote(md), unquote(tag)}, true}, state)

          do_parse(
            rest,
            %State{state | path: [{unquote(tag), unquote(attrs), []} | state.path]},
            {:nested, unquote(tag), level + 1}
          )
      end
    end

    defp do_parse(<<unquote(md), _::binary>> = input, state(), {:linefeed, pos}) do
      state = rewind_state(state, unquote(tag))
      do_parse(input, state, {:linefeed, pos})
    end
  end)

  Enum.each(@syntax[:list], fn {md, properties} ->
    tag = properties[:tag]
    outer = Map.get(properties, :outer, :ul)
    attrs = Macro.escape(properties[:attributes])

    defp do_parse(<<unquote(md), rest::binary>>, empty(), {:linefeed, pos}) do
      state = listener({:tag, {unquote(md), unquote(outer)}, true}, state)
      state = listener({:tag, {unquote(md), unquote(tag)}, true}, state)

      do_parse(
        rest,
        %State{
          state
          | path: [{unquote(tag), unquote(attrs), []}, {unquote(outer), unquote(attrs), []}],
            indent: pos
        },
        {:inner, unquote(tag), pos}
      )
    end

    defp do_parse(
           <<unquote(md), rest::binary>> = input,
           %State{path: [{unquote(tag), _, _} | _], indent: indent} = state,
           mode
         )
         when mode != :raw do
      case mode do
        {:linefeed, pos} ->
          do_parse(input, state, {:inner, unquote(tag), pos})

        {:inner, unquote(tag), pos} when pos == indent ->
          state = listener({:tag, {unquote(md), unquote(tag)}, false}, state)
          state = rewind_state(state, unquote(outer))
          state = listener({:tag, {unquote(md), unquote(tag)}, true}, state)

          do_parse(
            rest,
            %State{state | path: [{unquote(tag), unquote(attrs), []} | state.path]},
            {:inner, unquote(tag), pos}
          )

        {:inner, unquote(tag), pos} when pos > indent ->
          state = listener({:tag, {unquote(md), unquote(tag)}, false}, state)
          state = rewind_state(state, unquote(outer))
          state = listener({:tag, {unquote(md), unquote(tag)}, true}, state)
          state = listener({:tag, {unquote(md), unquote(outer)}, true}, state)
          state = listener({:tag, {unquote(md), unquote(tag)}, true}, state)

          do_parse(
            rest,
            %State{
              state
              | path: [
                  {unquote(tag), unquote(attrs), []},
                  {unquote(outer), unquote(attrs), []},
                  {unquote(tag), unquote(attrs), []} | state.path
                ],
                indent: pos
            },
            {:inner, unquote(tag), pos}
          )

        {:inner, unquote(tag), pos} when pos < indent ->
          state = listener({:tag, {unquote(md), unquote(tag)}, false}, state)
          state = rewind_state(state, unquote(outer))
          state = listener({:tag, {unquote(md), unquote(outer)}, false}, state)
          state = to_ast(state)
          state = rewind_state(state, unquote(outer))
          state = listener({:tag, {unquote(md), unquote(tag)}, true}, state)

          do_parse(
            rest,
            %State{
              state
              | path: [{unquote(tag), unquote(attrs), []} | state.path],
                indent: pos
            },
            {:inner, unquote(tag), pos}
          )
      end
    end

    defp do_parse(<<unquote(md), _::binary>> = input, state(), {:linefeed, pos}) do
      state = rewind_state(state, unquote(tag))
      do_parse(input, state, {:linefeed, pos})
    end
  end)

  Enum.each(@syntax[:brace], fn {md, properties} ->
    tag = properties[:tag]
    attrs = Macro.escape(properties[:attributes])

    defp do_parse(
           <<unquote(md), rest::binary>>,
           %State{path: [{unquote(tag), _, _} | _]} = state,
           mode
         )
         when mode != :raw do
      state = listener({:tag, {unquote(md), unquote(tag)}, false}, state)
      do_parse(rest, to_ast(state), :md)
    end

    defp do_parse(<<unquote(md), rest::binary>>, state(), mode) when mode != :raw do
      state = listener({:tag, {unquote(md), unquote(tag)}, true}, state)

      do_parse(
        rest,
        %State{state | path: [{unquote(tag), unquote(attrs), []} | state.path]},
        :md
      )
    end
  end)

  ## plain text handlers

  defp do_parse(<<x::utf8, rest::binary>>, state(), mode) do
    state = listener({:char, <<x::utf8>>}, state)

    state =
      case mode do
        {:nested, tag, level} ->
          current_level = level(state, tag)

          # Backward compatible version of
          # Enum.reduce(level..(current_level - 1)//1, state, fn _, state ->
          for i <- level..current_level, i > level, reduce: state do
            acc -> acc |> rewind_state(tag) |> to_ast()
          end

        _ ->
          state
      end

    do_parse(rest, push_char(x, state, mode), :md)
  end

  defp do_parse("", state(), _) do
    state =
      :finalize
      |> listener(state)
      |> rewind_state()

    listener(:end, state)
  end

  ## helpers
  @spec listener(L.context(), L.state()) :: L.state()
  def listener(context, state) do
    case state.listener.element(context, state) do
      :ok -> state
      {:update, state} -> state
    end
  end

  @spec level(L.state(), L.element()) :: non_neg_integer()
  defp level(state(), tag),
    do: Enum.count(state.path, &match?({^tag, _, _}, &1))

  @spec rewind_state(L.state(), L.element()) :: L.state()
  defp rewind_state(state, stop_at \\ nil) do
    Enum.reduce_while(state.path, state, fn
      {^stop_at, _, _}, acc -> {:halt, acc}
      _, acc -> {:cont, to_ast(acc)}
    end)
  end

  @spec push_char(pos_integer() | binary(), L.state(), parse_mode()) :: L.state()
  defp push_char(x, state, mode) when is_integer(x),
    do: push_char(<<x::utf8>>, state, mode)

  defp push_char(x, state, mode) do
    path =
      case {mode, state.path} do
        {{:linefeed, _}, []} ->
          [{syntax()[:outer], nil, [x]}]

        # {{:linefeed, _}, path} ->
        #   [{syntax()[:outer], nil, [x]} | path]

        {_, [{elem, attrs, [txt | branch]} | rest]} when is_binary(txt) ->
          [{elem, attrs, [txt <> x | branch]} | rest]

        {_, [{elem, attrs, branch} | rest]} ->
          [{elem, attrs, [x | branch]} | rest]
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
