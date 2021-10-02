defmodule Md.Parser.Default do
  @moduledoc """
  Default skeleton parser implementation.
  """
  @behaviour Md.Parser

  @default_syntax [
    outer: :p,
    span: :span,
    fixes: %{
      img: :src
    },
    custom: [
      # {md, {handler, properties}}
    ],
    flush: [
      {"---", %{tag: :hr, rewind: true}},
      {"  \n", %{tag: :br}},
      {"  \n", %{tag: :br}}
    ],
    magnet: [
      {"http://", %{tag: :a, attribute: :href}},
      {"https://", %{tag: :a, attribute: :href}}
    ],
    block: [
      {"```", %{tag: [:pre, :code], mode: :raw}}
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
    list:
      [
        {"- ", %{tag: :li, outer: :ul}},
        {"* ", %{tag: :li, outer: :ul}},
        {"+ ", %{tag: :li, outer: :ul}}
      ] ++ Enum.map(0..100, &{"#{&1}. ", %{tag: :li, outer: :ol}}),
    brace: [
      {"*", %{tag: :b}},
      {"_", %{tag: :it}},
      {"**", %{tag: :strong, attributes: %{class: "red"}}},
      {"__", %{tag: :em}},
      {"~", %{tag: :s}},
      {"~~", %{tag: :del}},
      {"`", %{tag: :code, mode: :raw, attributes: %{class: "code-inline"}}}
    ]
  ]

  alias Md.Listener, as: L
  alias Md.Parser.State

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

  @impl Md.Parser
  def parse(input, listener \\ L.Debug) do
    %State{ast: ast, path: []} = state = do_parse(input, %State{listener: listener})
    %State{state | ast: Enum.reverse(ast)}
  end

  # helper macros
  defmacrop initial,
    do: quote(do: %State{mode: [:idle], path: [], ast: []} = var!(state))

  defmacrop empty(mode),
    do:
      quote(
        generated: true,
        do: %State{mode: [unquote(mode) = var!(mode) | _], path: []} = var!(state)
      )

  defmacrop state,
    do: quote(generated: true, do: %State{mode: [var!(mode) | _]} = var!(state))

  defmacrop state(mode),
    do: quote(generated: true, do: %State{mode: [unquote(mode) = var!(mode) | _]} = var!(state))

  defmacrop state_linefeed,
    do: quote(generated: true, do: %State{mode: [{:linefeed, var!(pos)} | _]} = var!(state))

  @spec do_parse(binary(), L.state()) :: L.state()
  defp do_parse(input, state)

  # :start
  defp do_parse(input, initial()) do
    state =
      state
      |> listener(:start)
      |> set_mode({:linefeed, 0})

    do_parse(input, state)
  end

  ## escaped symbol
  defp do_parse(<<?\\, x::utf8, rest::binary>>, state()) when mode != :raw do
    state =
      state
      |> listener({:esc, <<x::utf8>>})
      |> push_char(x)

    do_parse(rest, state)
  end

  Enum.each(@syntax[:custom], fn
    {md, {handler, properties}} when is_atom(handler) or is_function(handler, 2) ->
      rewind = Map.get(properties, :rewind, false)

      defp do_parse(<<unquote(md), rest::binary>>, state()) when mode != :raw do
        state =
          unquote(rewind)
          |> if(do: rewind_state(state), else: state)
          |> listener({:custom, {unquote(md), unquote(handler)}, nil})

        case handler do
          module when is_atom(module) -> module.do_parse(rest, state)
          fun when is_function(fun, 2) -> fun.(rest, state)
        end
      end
  end)

  Enum.each(@syntax[:flush], fn {md, properties} ->
    rewind = Map.get(properties, :rewind, false)
    [tag | _] = tags = List.wrap(properties[:tag])
    attrs = Macro.escape(properties[:attributes])

    defp do_parse(<<unquote(md), rest::binary>>, state()) when mode != :raw do
      state =
        unquote(rewind)
        |> if(do: rewind_state(state), else: state)
        |> listener({:tag, {unquote(md), unquote(tag)}, nil})
        |> push_path(for tag <- unquote(tags), do: {tag, unquote(attrs), []})
        |> rewind_state(until: unquote(tag), inclusive: true)
        |> set_mode({:linefeed, 0})

      do_parse(rest, state)
    end
  end)

  Enum.each(@syntax[:block], fn {md, properties} ->
    [tag | _] = tags = properties[:tag]
    mode = properties[:mode]
    attrs = Macro.escape(properties[:attributes])

    us = Macro.var(:_, %Macro.Env{}.context)
    closing_match = Enum.reduce(tags, [], &[{:{}, [], [&1, us, us]} | &2])

    defp do_parse(<<unquote(md), rest::binary>>, state_linefeed()) do
      state =
        state
        |> listener({:tag, {unquote(md), unquote(tag)}, true})
        |> push_path(for tag <- unquote(tags), do: {tag, unquote(attrs), []})
        |> set_mode(unquote(mode))

      do_parse(rest, state)
    end

    defp do_parse(
           <<unquote(md), rest::binary>>,
           %State{path: [unquote_splicing(closing_match) | _]} = state
         ) do
      state =
        state
        |> rewind_state()
        |> set_mode(:md)

      do_parse(rest, state)
    end
  end)

  # → :linefeed
  defp do_parse(<<?\n, rest::binary>>, state()) when mode == :md do
    state =
      state
      |> listener(:linefeed)
      |> push_char(?\s)
      |> set_mode({:linefeed, 0})

    do_parse(rest, state)
  end

  defp do_parse(<<?\n, rest::binary>>, state_linefeed()) do
    state =
      state
      |> listener(:break)
      |> rewind_state()
      |> replace_mode({:linefeed, 0})

    do_parse(rest, state)
  end

  ## linefeed mode
  defp do_parse(<<?\s, rest::binary>>, state_linefeed()) do
    state =
      state
      |> listener(:whitespace)
      |> replace_mode({:linefeed, pos + 1})

    do_parse(rest, state)
  end

  defp do_parse(<<?\s, rest::binary>>, %State{mode: [{:nested, _, _} | _]} = state) do
    do_parse(rest, state)
  end

  Enum.each(@syntax[:pair], fn {md, properties} ->
    tag = properties[:tag]
    closing = properties[:closing]
    outer = properties[:outer]
    inner_opening = properties[:inner_opening]
    inner_closing = properties[:inner_closing]
    inner_tag = Map.get(properties, :inner_tag, true)
    attrs = Macro.escape(properties[:attributes])

    defp do_parse(<<unquote(md), rest::binary>>, state()) when mode != :raw do
      state =
        state
        |> listener({:tag, {unquote(md), unquote(tag)}, unquote(inner_tag)})
        |> replace_mode(:md)
        |> push_path({unquote(tag), unquote(attrs), []})

      do_parse(rest, state)
    end

    defp do_parse(
           <<unquote(closing), unquote(inner_opening), rest::binary>>,
           %State{mode: [mode | _], path: [{unquote(tag), attrs, content} | path_tail]} = state
         )
         when mode != :raw do
      do_parse(rest, %State{
        state
        | bag: %{state.bag | stock: content},
          path: [{unquote(tag), attrs, []} | path_tail]
      })
    end

    defp do_parse(
           <<unquote(inner_closing), rest::binary>>,
           %State{
             mode: [mode | _],
             bag: %{stock: outer_content},
             path: [{unquote(tag), attrs, [content]} | path_tail]
           } = state
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

      state =
        %State{state | bag: %{state.bag | stock: []}, path: [final_tag | path_tail]}
        |> to_ast()
        |> replace_mode(:md)

      do_parse(rest, state)
    end
  end)

  Enum.each(@syntax[:paragraph], fn {md, properties} ->
    tag = properties[:tag]
    attrs = Macro.escape(properties[:attributes])

    defp do_parse(
           <<unquote(md), rest::binary>>,
           %State{path: [], mode: [{:linefeed, _pos} | _]} = state
         ) do
      state =
        state
        |> listener({:tag, {unquote(md), unquote(tag)}, true})
        |> replace_mode({:nested, unquote(tag), 1})
        |> push_path({unquote(tag), unquote(attrs), []})

      do_parse(rest, state)
    end

    defp do_parse(
           <<unquote(md), rest::binary>>,
           %State{mode: [mode | _], path: [{unquote(tag), _, _} | _]} = state
         )
         when mode != :raw do
      current_level = level(state, unquote(tag))

      case mode do
        {:linefeed, _} ->
          state = replace_mode(state, {:nested, unquote(tag), 1})
          do_parse(rest, state)

        :md ->
          state = push_char(state, unquote(md))
          do_parse(rest, state)

        {:nested, unquote(tag), level} when level < current_level ->
          state = replace_mode(state, {:nested, unquote(tag), level + 1})
          do_parse(rest, state)

        {:nested, unquote(tag), level} ->
          state =
            state
            |> listener({:tag, {unquote(md), unquote(tag)}, true})
            |> replace_mode({:nested, unquote(tag), level + 1})
            |> push_path({unquote(tag), unquote(attrs), []})

          do_parse(rest, state)
      end
    end

    defp do_parse(
           <<unquote(md), rest::binary>>,
           %State{mode: [{:nested, _, _} | _]} = state
         ) do
      state =
        state
        |> listener({:tag, {unquote(md), unquote(tag)}, true})
        |> replace_mode(:md)
        |> push_path({unquote(tag), unquote(attrs), []})

      do_parse(rest, state)
    end

    defp do_parse(<<unquote(md), _::binary>> = input, state_linefeed()) do
      state = rewind_state(state, until: unquote(tag))
      do_parse(input, state)
    end
  end)

  Enum.each(@syntax[:list], fn {md, properties} ->
    tag = properties[:tag]
    outer = Map.get(properties, :outer, :ul)
    attrs = Macro.escape(properties[:attributes])

    defp do_parse(
           <<unquote(md), rest::binary>>,
           %State{path: [], mode: [{:linefeed, pos} | _]} = state
         ) do
      state =
        state
        |> listener({:tag, {unquote(md), unquote(outer)}, true})
        |> listener({:tag, {unquote(md), unquote(tag)}, true})
        |> replace_mode({:inner, unquote(tag), pos})
        |> push_path([{unquote(outer), unquote(attrs), []}, {unquote(tag), unquote(attrs), []}])

      do_parse(rest, %State{state | bag: %{state.bag | indent: [pos]}})
    end

    defp do_parse(
           <<unquote(md), rest::binary>> = input,
           %State{
             mode: [mode | _],
             path: [{unquote(tag), _, _} | _],
             bag: %{indent: [indent | _] = indents}
           } = state
         )
         when mode != :raw do
      case mode do
        {:linefeed, pos} ->
          state =
            state
            |> rewind_state(until: unquote(tag))
            |> replace_mode({:inner, unquote(tag), pos})

          do_parse(input, state)

        {:inner, unquote(tag), ^indent} ->
          state =
            state
            |> rewind_state(until: unquote(outer))
            |> listener({:tag, {unquote(md), unquote(tag)}, true})
            |> replace_mode({:inner, unquote(tag), indent})
            |> push_path({unquote(tag), unquote(attrs), []})

          do_parse(rest, state)

        {:inner, unquote(tag), pos} when pos > indent ->
          state =
            state
            |> rewind_state(until: unquote(outer))
            |> listener({:tag, {unquote(md), unquote(outer)}, true})
            |> listener({:tag, {unquote(md), unquote(tag)}, true})
            |> replace_mode({:inner, unquote(tag), pos})
            |> push_path([
              {unquote(outer), unquote(attrs), []},
              {unquote(tag), unquote(attrs), []}
            ])

          do_parse(rest, %State{state | bag: %{state.bag | indent: [pos | indents]}})

        {:inner, unquote(tag), pos} when pos < indent ->
          {skipped, indents} = Enum.split_with(indents, &(&1 > pos))

          state =
            state
            |> rewind_state(until: unquote(outer), count: Enum.count(skipped), inclusive: false)
            |> listener({:tag, {unquote(md), unquote(tag)}, true})
            |> replace_mode({:inner, unquote(tag), pos})
            |> push_path({unquote(tag), unquote(attrs), []})

          do_parse(rest, %State{state | bag: %{state.bag | indent: indents}})
      end
    end

    defp do_parse(<<unquote(md), _::binary>> = input, state_linefeed()) do
      state = rewind_state(state, until: unquote(tag))
      do_parse(input, state)
    end
  end)

  Enum.each(@syntax[:brace], fn {md, properties} ->
    tag = properties[:tag]
    mode = properties[:mode]
    attrs = Macro.escape(properties[:attributes])

    defp do_parse(
           <<unquote(md), rest::binary>>,
           %State{mode: [mode | _], path: [{unquote(tag), _, _} | _]} = state
         )
         when mode == unquote(mode) or mode != :raw do
      state =
        state
        |> to_ast()
        |> pop_mode(unquote(mode))

      do_parse(rest, state)
    end

    defp do_parse(<<unquote(md), rest::binary>>, state()) when mode != :raw do
      state =
        state
        |> listener({:tag, {unquote(md), unquote(tag)}, true})
        |> push_mode(unquote(mode))
        |> push_path({unquote(tag), unquote(attrs), []})

      do_parse(rest, state)
    end
  end)

  ## plain text handlers

  defp do_parse(<<x::utf8, rest::binary>>, state()) do
    state = listener(state, {:char, <<x::utf8>>})

    state =
      mode
      |> case do
        {:nested, tag, level} ->
          current_level = level(state, tag)
          rewind_state(state, until: tag, count: current_level - level, inclusive: true)

        _ ->
          state
      end
      |> push_char(x)
      |> replace_mode(if mode in [:raw, :md], do: mode, else: :md)

    do_parse(rest, state)
  end

  defp do_parse("", state()) do
    state =
      state
      |> listener(:finalize)
      |> rewind_state()

    state = %State{state | mode: [:finished], bag: %{indent: [], stock: []}}

    listener(state, :end)
  end

  @spec push_char(L.state(), pos_integer() | binary()) :: L.state()
  defp push_char(state, x) when is_integer(x),
    do: push_char(state, <<x::utf8>>)

  defp push_char(state(), x) do
    path =
      case {x, mode, state.path} do
        {<<?\s>>, {:linefeed, _}, []} ->
          []

        {x, {:linefeed, _}, []} ->
          [{syntax()[:outer], nil, [x]}]

        {<<?\s>>, :md, []} ->
          []

        {_, :md, []} ->
          [{syntax()[:span], nil, [x]}]

        # {_, {:linefeed, _}, path} ->
        #   [{syntax()[:outer], nil, [x]} | path]

        {_, _, [{elem, attrs, [txt | branch]} | rest]} when is_binary(txt) ->
          [{elem, attrs, [txt <> x | branch]} | rest]

        {_, _, [{elem, attrs, branch} | rest]} ->
          [{elem, attrs, [x | branch]} | rest]
      end

    %State{state | path: path}
  end

  ## helpers
  @spec listener(L.state(), L.context()) :: L.state()
  def listener(state, context) do
    case state.listener.element(context, state) do
      :ok -> state
      {:update, state} -> state
    end
  end

  @spec level(L.state(), L.element()) :: non_neg_integer()
  defp level(state(), tag),
    do: Enum.count(state.path, &match?({^tag, _, _}, &1))

  @spec set_mode(L.state(), L.parse_mode()) :: L.state()
  defp set_mode(state(), value), do: %State{state | mode: [value]}

  @spec replace_mode(L.state(), L.parse_mode() | nil) :: L.state()
  defp replace_mode(state(), nil), do: state

  defp replace_mode(%State{mode: [_ | modes]} = state, value),
    do: %State{state | mode: [value | modes]}

  @spec push_mode(L.state(), L.parse_mode()) :: L.state()
  defp push_mode(state(), nil), do: state
  defp push_mode(state(), value), do: %State{state | mode: [value | state.mode]}

  @dialyzer {:nowarn_function, pop_mode: 2}
  # @spec pop_mode(L.state()) :: L.state()
  # defp pop_mode(state()), do: %State{state | mode: tl(state.mode)}
  @spec pop_mode(L.state(), L.element()) :: L.state()
  defp pop_mode(state(), mode), do: %State{state | mode: tl(state.mode)}
  defp pop_mode(state(), _), do: state

  @spec push_path(L.state(), L.branch() | [L.branch()]) :: L.state()
  defp push_path(state(), elements) when is_list(elements),
    do: Enum.reduce(elements, state, &push_path(&2, &1))

  defp push_path(%State{path: path} = state, element),
    do: %State{state | path: [element | path]}

  @spec rewind_state(L.state(), [
          {:until, L.element()} | {:count, pos_integer()} | {:inclusive, boolean()}
        ]) :: L.state()
  defp rewind_state(state, params \\ []) do
    until = Keyword.get(params, :until, nil)
    count = Keyword.get(params, :count, 1)
    inclusive = Keyword.get(params, :inclusive, false)

    for i <- 1..count, count > 0, reduce: state do
      acc ->
        state =
          Enum.reduce_while(state.path, acc, fn
            {^until, _, _}, acc -> {:halt, acc}
            _, acc -> {:cont, to_ast(acc)}
          end)

        if i < count or inclusive, do: to_ast(state), else: state
    end
  end

  @spec fix_element(L.branch()) :: L.branch()
  Enum.each(@syntax[:fixes], fn {tag, attribute} ->
    defp fix_element({unquote(tag), attrs, [attr | content]}),
      do: {unquote(tag), Map.put(attrs || %{}, unquote(attribute), attr), content}
  end)

  defp fix_element(element), do: element

  @spec to_ast(L.state()) :: L.state()
  defp to_ast(%State{path: []} = state), do: state

  defp to_ast(%State{path: [{tag, _, _} = last], ast: ast} = state) do
    state = %State{state | path: [], ast: [reverse(last) | ast]}
    listener(state, {:tag, tag, false})
  end

  defp to_ast(%State{path: [{tag, _, _} = last, {elem, attrs, branch} | rest]} = state) do
    state = %State{state | path: [{elem, attrs, [reverse(last) | branch]} | rest]}
    listener(state, {:tag, tag, false})
  end

  @spec reverse(L.trace()) :: L.trace()
  defp reverse({elem, attrs, branch}) when is_list(branch),
    do: {elem, attrs, Enum.reverse(branch)}

  defp reverse(any), do: any
end
