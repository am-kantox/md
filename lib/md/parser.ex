defmodule Md.Parser do
  @default_syntax [
    outer: :p,
    span: :span,
    fixes: %{
      img: :src
    },
    flush: [
      {"---", %{tag: :hr, rewind: true}},
      {"  \n", %{tag: :br}},
      {"  \n", %{tag: :br}}
    ],
    magnet: [
      {"¡", %{tag: :abbr}}
    ],
    pair: [
      {"![",
       %{
         tag: :figure,
         closing: "]",
         inner_opening: "(",
         inner_closing: ")",
         inner_tag: :img,
         outer: {:tag, :figcaption}
       }},
      {"?[",
       %{
         tag: :abbr,
         closing: "]",
         inner_opening: "(",
         inner_closing: ")",
         outer: {:attribute, :title}
       }},
      {"[",
       %{
         tag: :a,
         closing: "]",
         inner_opening: "(",
         inner_closing: ")",
         outer: {:attribute, :href}
       }}
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
      {"- ", %{tag: :li, outer: :ul}},
      {"* ", %{tag: :li, outer: :ul}},
      {"+ ", %{tag: :li, outer: :ul}},
      {"1. ", %{tag: :li, outer: :ol}},
      {"2. ", %{tag: :li, outer: :ol}},
      {"3. ", %{tag: :li, outer: :ol}},
      {"4. ", %{tag: :li, outer: :ol}},
      {"5. ", %{tag: :li, outer: :ol}},
      {"6. ", %{tag: :li, outer: :ol}},
      {"7. ", %{tag: :li, outer: :ol}},
      {"8. ", %{tag: :li, outer: :ol}},
      {"9. ", %{tag: :li, outer: :ol}},
      {"10. ", %{tag: :li, outer: :ol}}
    ],
    brace: [
      {"*", %{tag: :b}},
      {"_", %{tag: :it}},
      {"**", %{tag: :strong, attributes: %{class: "red"}}},
      {"__", %{tag: :em}},
      {"~", %{tag: :s}},
      {"~~", %{tag: :del}},
      {"`", %{tag: :code, attributes: %{class: "code-inline"}}}
    ]
  ]

  alias Md.Listener, as: L

  defmodule State do
    @moduledoc """
    The internal state of the parser.
    """
    defstruct path: [], ast: [], mode: :none, listener: nil, bag: %{indent: [], stock: []}
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

  @spec do_parse(binary(), L.state(), L.parse_mode()) :: L.state()
  defp do_parse(input, state, mode)

  # :start
  defp do_parse(input, initial(), :none) do
    state = listener(:none, :start, state)
    do_parse(input, state, {:linefeed, 0})
  end

  ## escaped symbol
  defp do_parse(<<?\\, x::utf8, rest::binary>>, state(), mode) when mode != :raw do
    state = listener(mode, {:esc, <<x::utf8>>}, state)
    do_parse(<<x::utf8, rest::binary>>, state, :raw)
  end

  Enum.each(@syntax[:flush], fn {md, properties} ->
    rewind = Map.get(properties, :rewind, false)
    tag = properties[:tag]
    attrs = Macro.escape(properties[:attributes])

    defp do_parse(<<unquote(md), rest::binary>>, state(), mode) when mode != :raw do
      state = if unquote(rewind), do: rewind_state(state), else: state
      state = listener(mode, {:tag, {unquote(md), unquote(tag)}, nil}, state)

      state =
        to_ast(mode, %State{state | path: [{unquote(tag), unquote(attrs), []} | state.path]})

      do_parse(rest, state, {:linefeed, 0})
    end
  end)

  # → :linefeed
  defp do_parse(<<?\n, rest::binary>>, state(), :md) do
    state = listener(:md, :linefeed, state)
    do_parse(rest, push_char(?\s, state, :md), {:linefeed, 0})
  end

  defp do_parse(<<?\n, rest::binary>>, state(), {:linefeed, pos}) do
    state = listener({:linefeed, pos}, :break, state)
    do_parse(rest, rewind_state(state), {:linefeed, 0})
  end

  ## linefeed mode
  defp do_parse(<<?\s, rest::binary>>, state(), {:linefeed, pos}) do
    state = listener({:linefeed, pos}, :whitespace, state)
    do_parse(rest, state, {:linefeed, pos + 1})
  end

  defp do_parse(<<?\s, rest::binary>>, state(), {:nested, _, _} = nested) do
    do_parse(rest, state, nested)
  end

  Enum.each(@syntax[:pair], fn {md, properties} ->
    tag = properties[:tag]
    closing = properties[:closing]
    outer = properties[:outer]
    inner_opening = properties[:inner_opening]
    inner_closing = properties[:inner_closing]
    inner_tag = Map.get(properties, :inner_tag, true)
    attrs = Macro.escape(properties[:attributes])

    defp do_parse(<<unquote(md), rest::binary>>, state(), mode) when mode != :raw do
      state = listener(mode, {:tag, {unquote(md), unquote(tag)}, unquote(inner_tag)}, state)

      do_parse(
        rest,
        %State{state | path: [{unquote(tag), unquote(attrs), []} | state.path]},
        :md
      )
    end

    defp do_parse(
           <<unquote(closing), unquote(inner_opening), rest::binary>>,
           %State{path: [{unquote(tag), attrs, content} | path_tail]} = state,
           mode
         )
         when mode != :raw do
      bag = %{state.bag | stock: content}

      do_parse(
        rest,
        %State{state | bag: bag, path: [{unquote(tag), attrs, []} | path_tail]},
        mode
      )
    end

    defp do_parse(
           <<unquote(inner_closing), rest::binary>>,
           %State{
             bag: %{stock: outer_content},
             path: [{unquote(tag), attrs, [content]} | path_tail]
           } = state,
           mode
         )
         when mode != :raw do
      final_tag =
        case unquote(outer) do
          {:tag, {tag, attr}} ->
            {unquote(tag), attrs,
             [
               {unquote(inner_tag), %{attr => content}, []},
               {tag, nil, outer_content}
             ]}

          {:tag, tag} ->
            {unquote(tag), attrs,
             [
               fix_element({unquote(inner_tag), nil, [content]}),
               {tag, nil, outer_content}
             ]}

          {:attribute, attribute} ->
            {unquote(tag), Map.put(attrs || %{}, attribute, content), outer_content}
        end

      bag = %{state.bag | stock: []}
      state = to_ast(mode, %State{state | bag: bag, path: [final_tag | path_tail]})
      do_parse(rest, state, :md)
    end
  end)

  Enum.each(@syntax[:paragraph], fn {md, properties} ->
    tag = properties[:tag]
    attrs = Macro.escape(properties[:attributes])

    defp do_parse(<<unquote(md), rest::binary>>, empty(), {:linefeed, pos}) do
      state = listener({:linefeed, pos}, {:tag, {unquote(md), unquote(tag)}, true}, state)

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
          state = listener(mode, {:tag, {unquote(md), unquote(tag)}, true}, state)

          do_parse(
            rest,
            %State{state | path: [{unquote(tag), unquote(attrs), []} | state.path]},
            {:nested, unquote(tag), level + 1}
          )
      end
    end

    defp do_parse(<<unquote(md), rest::binary>>, state(), {:nested, _, _} = mode) do
      state = listener(mode, {:tag, {unquote(md), unquote(tag)}, true}, state)

      do_parse(
        rest,
        %State{state | path: [{unquote(tag), unquote(attrs), []}]},
        :md
      )
    end

    defp do_parse(<<unquote(md), _::binary>> = input, state(), {:linefeed, pos}) do
      state = rewind_state(state, until: unquote(tag))
      do_parse(input, state, {:linefeed, pos})
    end
  end)

  Enum.each(@syntax[:list], fn {md, properties} ->
    tag = properties[:tag]
    outer = Map.get(properties, :outer, :ul)
    attrs = Macro.escape(properties[:attributes])

    defp do_parse(<<unquote(md), rest::binary>>, empty(), {:linefeed, pos}) do
      state = listener({:linefeed, pos}, {:tag, {unquote(md), unquote(outer)}, true}, state)
      state = listener({:linefeed, pos}, {:tag, {unquote(md), unquote(tag)}, true}, state)
      bag = %{state.bag | indent: [pos]}

      do_parse(
        rest,
        %State{
          state
          | path: [{unquote(tag), unquote(attrs), []}, {unquote(outer), unquote(attrs), []}],
            bag: bag
        },
        {:inner, unquote(tag), pos}
      )
    end

    defp do_parse(
           <<unquote(md), rest::binary>> = input,
           %State{path: [{unquote(tag), _, _} | _], bag: %{indent: [indent | _] = indents}} =
             state,
           mode
         )
         when mode != :raw do
      case mode do
        {:linefeed, pos} ->
          state = rewind_state(state, until: unquote(tag))
          do_parse(input, state, {:inner, unquote(tag), pos})

        {:inner, unquote(tag), ^indent} ->
          state = rewind_state(state, until: unquote(outer))
          state = listener(mode, {:tag, {unquote(md), unquote(tag)}, true}, state)

          do_parse(
            rest,
            %State{state | path: [{unquote(tag), unquote(attrs), []} | state.path]},
            {:inner, unquote(tag), indent}
          )

        {:inner, unquote(tag), pos} when pos > indent ->
          state = rewind_state(state, until: unquote(outer))
          state = listener(mode, {:tag, {unquote(md), unquote(outer)}, true}, state)
          state = listener(mode, {:tag, {unquote(md), unquote(tag)}, true}, state)
          bag = %{state.bag | indent: [pos | indents]}

          do_parse(
            rest,
            %State{
              state
              | path: [
                  {unquote(tag), unquote(attrs), []},
                  {unquote(outer), unquote(attrs), []} | state.path
                ],
                bag: bag
            },
            {:inner, unquote(tag), pos}
          )

        {:inner, unquote(tag), pos} when pos < indent ->
          {skipped, indents} = Enum.split_with(indents, &(&1 > pos))

          state =
            Enum.reduce(skipped, state, fn _, state ->
              state = rewind_state(state, until: unquote(outer))
              to_ast(mode, state)
            end)

          state = rewind_state(state, until: unquote(outer))
          state = listener(mode, {:tag, {unquote(md), unquote(tag)}, true}, state)
          bag = %{state.bag | indent: indents}

          do_parse(
            rest,
            %State{
              state
              | path: [{unquote(tag), unquote(attrs), []} | state.path],
                bag: bag
            },
            {:inner, unquote(tag), pos}
          )
      end
    end

    defp do_parse(<<unquote(md), _::binary>> = input, state(), {:linefeed, pos}) do
      state = rewind_state(state, until: unquote(tag))
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
      do_parse(rest, to_ast(mode, state), mode)
    end

    defp do_parse(<<unquote(md), rest::binary>>, state(), mode) when mode != :raw do
      state = listener(mode, {:tag, {unquote(md), unquote(tag)}, true}, state)

      do_parse(
        rest,
        %State{state | path: [{unquote(tag), unquote(attrs), []} | state.path]},
        mode
      )
    end
  end)

  ## plain text handlers

  defp do_parse(<<x::utf8, rest::binary>>, state(), mode) do
    state = listener(mode, {:char, <<x::utf8>>}, state)

    state =
      case mode do
        {:nested, tag, level} ->
          current_level = level(state, tag)

          # Backward compatible version of
          # Enum.reduce(level..(current_level - 1)//1, state, fn _, state ->
          for i <- level..current_level, i > level, reduce: state do
            acc -> rewind_state(acc, until: tag, count: 1)
          end

        _ ->
          state
      end

    do_parse(rest, push_char(x, state, mode), :md)
  end

  defp do_parse("", state(), mode) do
    state =
      mode
      |> listener(:finalize, state)
      |> rewind_state()

    state = %State{state | bag: %{indent: [], stock: []}}

    listener(mode, :end, state)
  end

  ## helpers
  @spec listener(L.parse_mode(), L.context(), L.state()) :: L.state()
  def listener(mode, context, state) do
    case state.listener.element(context, %State{state | mode: mode}) do
      :ok -> state
      {:update, state} -> state
    end
  end

  @spec level(L.state(), L.element()) :: non_neg_integer()
  defp level(state(), tag),
    do: Enum.count(state.path, &match?({^tag, _, _}, &1))

  @spec rewind_state(L.state(), [{:until, L.element()} | {:count, pos_integer()}]) :: L.state()
  defp rewind_state(state, params \\ []) do
    until = Keyword.get(params, :until, nil)
    count = Keyword.get(params, :count, 0)
    # FIXME
    mode = :rewind

    state =
      Enum.reduce_while(state.path, state, fn
        {^until, _, _}, acc -> {:halt, acc}
        _, acc -> {:cont, to_ast(mode, acc)}
      end)

    if count > 0,
      do: Enum.reduce(1..count, state, fn _, acc -> to_ast(mode, acc) end),
      else: state
  end

  @spec push_char(pos_integer() | binary(), L.state(), L.parse_mode()) :: L.state()
  defp push_char(x, state, mode) when is_integer(x),
    do: push_char(<<x::utf8>>, state, mode)

  defp push_char(x, state, mode) do
    path =
      case {mode, state.path} do
        {{:linefeed, _}, []} ->
          [{syntax()[:outer], nil, [x]}]

        {:md, []} ->
          [{syntax()[:span], nil, [x]}]

        # {{:linefeed, _}, path} ->
        #   [{syntax()[:outer], nil, [x]} | path]

        {_, [{elem, attrs, [txt | branch]} | rest]} when is_binary(txt) ->
          [{elem, attrs, [txt <> x | branch]} | rest]

        {_, [{elem, attrs, branch} | rest]} ->
          [{elem, attrs, [x | branch]} | rest]
      end

    %State{state | path: path}
  end

  @spec fix_element(L.branch()) :: L.branch()
  Enum.each(@syntax[:fixes], fn {tag, attribute} ->
    defp fix_element({unquote(tag), attrs, [attr | content]}),
      do: {unquote(tag), Map.put(attrs || %{}, unquote(attribute), attr), content}
  end)

  defp fix_element(element), do: element

  @spec to_ast(L.parse_mode(), L.state()) :: L.state()
  defp to_ast(_, %State{path: []} = state), do: state

  defp to_ast(mode, %State{path: [{tag, _, _} = last], ast: ast} = state) do
    state = %State{state | path: [], ast: [reverse(last) | ast]}
    listener(mode, {:tag, tag, false}, state)
  end

  defp to_ast(mode, %State{path: [{tag, _, _} = last, {elem, attrs, branch} | rest]} = state) do
    state = %State{state | path: [{elem, attrs, [reverse(last) | branch]} | rest]}
    listener(mode, {:tag, tag, false}, state)
  end

  @spec reverse(L.trace()) :: L.trace()
  defp reverse({elem, attrs, branch}) when is_list(branch),
    do: {elem, attrs, Enum.reverse(branch)}

  defp reverse(any), do: any
end
