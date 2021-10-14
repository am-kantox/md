defmodule Md.Parser.Default do
  @moduledoc false

  import Md.Utils

  alias Md.Listener, as: L
  alias Md.Parser.State

  @behaviour Md.Parser

  @ol_max Application.compile_env(:md, :ol_max, 10)
  @disclosure_range 3..5

  @default_syntax %{
    settings: %{
      outer: :p,
      span: :span,
      disclosure_range: @disclosure_range,
      empty_tags: ~w|img hr br|a
    },
    custom: [
      # {md, {handler, properties}}
    ],
    substitute: [
      {"<", %{text: "&lt;"}},
      {"&", %{text: "&amp;"}}
    ],
    escape: [
      {"\\", %{}}
    ],
    comment: [
      {"<!--", %{closing: "-->"}}
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
      {"```", %{tag: [:pre, :code], mode: :raw, pop: %{code: :class}}}
    ],
    shift: [
      {"    ", %{tag: [:div, :pre, :code], mode: {:inner, :raw}}}
    ],
    pair: [
      {"![",
       %{
         tag: :figure,
         closing: "]",
         inner_opening: "(",
         inner_closing: ")",
         inner_tag: :img,
         outer: {:tag, {:figcaption, :src}}
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
         disclosure_opening: "[",
         disclosure_closing: "]",
         outer: {:attribute, :href}
       }}
    ],
    disclosure: [
      {":", %{until: :eol}}
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
      ] ++ Enum.map(0..@ol_max, &{"#{&1}. ", %{tag: :li, outer: :ol}}),
    brace: [
      {"*", %{tag: :b}},
      {"_", %{tag: :it}},
      {"**", %{tag: :strong, attributes: %{class: "red"}}},
      {"__", %{tag: :em}},
      {"~", %{tag: :s}},
      {"~~", %{tag: :del}},
      {"``", %{tag: :span, mode: :raw, attributes: %{class: "code-inline"}}},
      {"`", %{tag: :code, mode: :raw, attributes: %{class: "code-inline"}}}
    ]
  }

  @custom_syntax Application.compile_env(:md, :syntax, %{})
  @syntax @default_syntax
          |> Map.merge(@custom_syntax, fn
            _k, v1, v2 ->
              [v2, v1] |> Enum.map(&Map.new/1) |> Enum.reduce(&Map.merge/2) |> Map.to_list()
          end)
          |> Enum.map(fn
            {k, v} when is_list(v) ->
              {k, Enum.sort_by(v, &(-String.length(elem(&1, 0))))}

            {k, v} ->
              {k, v}
          end)

  @compile {:inline, syntax: 0}
  def syntax, do: @syntax

  @impl Md.Parser
  def parse(input, listener \\ nil) do
    %State{ast: ast, path: []} = state = do_parse(input, %State{listener: listener})
    {"", %State{state | ast: Enum.reverse(ast)}}
  end

  # helper macros
  defguardp is_md(mode) when mode == :md
  defguardp is_comment(mode) when mode == :comment
  defguardp is_raw(mode) when mode in [:raw, {:inner, :raw}]

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

  ## escaped symbols
  Enum.each(@syntax[:escape], fn {md, _} ->
    defp do_parse(unquote(md) <> <<x::utf8, rest::binary>>, state()) when not is_raw(mode) do
      state =
        state
        |> listener({:esc, <<x::utf8>>})
        |> push_char(x)

      do_parse(rest, state)
    end
  end)

  ## comments
  Enum.each(@syntax[:comment], fn {md, properties} ->
    closing = Map.get(properties, :closing, md)
    _tag = Map.get(properties, :tag, :comment)

    defp do_parse(unquote(closing) <> rest, state()) when is_comment(mode) do
      state =
        state
        |> listener({:comment, state.bag.stock})
        |> pop_mode(:comment)

      do_parse(rest, state)
    end

    defp do_parse(<<x::utf8, rest::binary>>, state()) when is_comment(mode) do
      [stock] = state.bag.stock
      state = %State{state | bag: %{state.bag | stock: [<<x::utf8>> <> stock]}}
      do_parse(rest, state)
    end

    defp do_parse(unquote(md) <> rest, state()) when not is_raw(mode) do
      state =
        %State{state | bag: %{state.bag | stock: [""]}}
        |> push_mode(:comment)

      do_parse(rest, state)
    end
  end)

  Enum.each(@syntax[:custom], fn
    {md, {handler, properties}} when is_atom(handler) or is_function(handler, 2) ->
      rewind = Map.get(properties, :rewind, false)

      defp do_parse(<<unquote(md), rest::binary>>, state()) when not is_raw(mode) do
        state =
          unquote(rewind)
          |> if(do: rewind_state(state), else: state)
          |> listener({:custom, {unquote(md), unquote(handler)}, nil})

        {continuation, state} =
          case handler do
            module when is_atom(module) -> module.do_parse(rest, state)
            fun when is_function(fun, 2) -> fun.(rest, state)
          end

        do_parse(continuation, state)
      end
  end)

  Enum.each(@syntax[:substitute], fn {md, properties} ->
    text = Map.get(properties, :text, "")

    defp do_parse(<<unquote(md), rest::binary>>, state()) do
      state =
        state
        |> listener({:substitute, unquote(md), unquote(text)})
        |> push_char(unquote(text))

      do_parse(rest, state)
    end
  end)

  Enum.each(@syntax[:flush], fn {md, properties} ->
    rewind = Map.get(properties, :rewind, false)
    [tag | _] = tags = List.wrap(properties[:tag])
    attrs = Macro.escape(properties[:attributes])

    defp do_parse(<<unquote(md), rest::binary>>, state()) when not is_raw(mode) do
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

  disclosure_range = Map.get(@syntax[:settings], :disclosure_range, @disclosure_range)

  # disclosure_range =
  #   if Version.compare(System.version(), "1.12.0") == :lt do
  #     Range.new(disclosure_range.last, disclosure_range.first)
  #   else
  #     Range.new(disclosure_range.last, disclosure_range.first, -1)
  #   end

  Enum.each(@syntax[:disclosure], fn {md, properties} ->
    until = Map.get(properties, :until, :eol)

    until =
      case until do
        :eol -> "\n"
        chars when is_binary(chars) -> chars
      end

    Enum.each(disclosure_range, fn len ->
      defp do_parse(
             <<disclosure::binary-size(unquote(len)), unquote(md), rest::binary>> = input,
             %State{
               mode: [{:linefeed, pos} | _],
               bag: %{deferred: deferreds}
             } = state
           ) do
        if disclosure in deferreds do
          state =
            state
            |> replace_mode({:inner, :raw})
            |> push_path({:__deferred__, disclosure, []})

          do_parse(rest, state)
        else
          <<c::binary-size(1), rest::binary>> = input

          state =
            state
            |> pop_mode([{:linefeed, pos}, :md])
            |> push_mode({:linefeed, pos})
            |> push_char(c)

          do_parse(rest, state)
        end
      end
    end)

    defp do_parse(
           <<unquote(until), rest::binary>>,
           %State{
             mode: [mode | _],
             path: [{:__deferred__, disclosure, [content]} | path]
           } = state
         )
         when is_raw(mode) do
      deferred = [{disclosure, content} | state.bag.deferred]

      state =
        %State{state | bag: Map.put(state.bag, :deferred, deferred), path: path}
        |> replace_mode({:linefeed, 0})

      do_parse(rest, state)
    end
  end)

  Enum.each(@syntax[:block], fn {md, properties} ->
    [tag | _] = tags = List.wrap(properties[:tag])
    mode = properties[:mode]
    attrs = Macro.escape(properties[:attributes])
    pop = Macro.escape(properties[:pop])

    closing_match = closing_match(tags)

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
        |> rewind_state(pop: unquote(pop))
        |> pop_mode(unquote(mode))
        |> push_mode(:md)

      do_parse(rest, state)
    end
  end)

  Enum.each(@syntax[:shift], fn {md, properties} ->
    [tag | _] = tags = List.wrap(properties[:tag])
    mode = properties[:mode]
    attrs = Macro.escape(properties[:attributes])

    closing_match = closing_match(tags)

    defp do_parse(
           <<unquote(md), rest::binary>>,
           %State{mode: [{:linefeed, 0} | _], path: [unquote_splicing(closing_match) | _]} = state
         ) do
      state =
        state
        |> pop_mode({:linefeed, 0})
        |> push_mode(unquote(mode))

      do_parse(rest, state)
    end

    defp do_parse(
           <<unquote(md), rest::binary>>,
           %State{
             mode: [{:nested, _tag, _level} | _],
             path: [unquote_splicing(closing_match) | _]
           } = state
         ) do
      state =
        state
        |> push_mode(unquote(mode))

      do_parse(rest, state)
    end

    defp do_parse(
           input,
           %State{
             mode: [{:linefeed, 0}, unquote(mode), {:nested, _, _} = nested | modes],
             path: [unquote_splicing(closing_match) | _]
           } = state
         ) do
      state = %State{state | mode: [nested, unquote(mode) | modes]}

      do_parse(input, state)
    end

    defp do_parse(
           input,
           %State{mode: [{:linefeed, 0} | _], path: [unquote_splicing(closing_match) | _]} = state
         ) do
      state =
        state
        |> rewind_state(until: unquote(tag), inclusive: true)
        |> pop_mode([{:linefeed, 0}, unquote(mode)])
        |> push_mode({:linefeed, 0})

      do_parse(input, state)
    end

    defp do_parse(<<unquote(md), rest::binary>>, empty({:linefeed, 0})) do
      state =
        state
        |> listener({:tag, {unquote(md), unquote(tag)}, true})
        |> pop_mode([{:linefeed, 0}, :md])
        |> push_mode(unquote(mode))
        |> push_path(for tag <- unquote(tags), do: {tag, unquote(attrs), []})

      do_parse(rest, state)
    end

    defp do_parse(<<unquote(md), rest::binary>>, state({:nested, _tag, _level})) do
      state =
        state
        |> listener({:tag, {unquote(md), unquote(tag)}, true})
        |> push_mode(unquote(mode))
        |> push_path(for tag <- unquote(tags), do: {tag, unquote(attrs), []})

      do_parse(rest, state)
    end

    defp do_parse(
           <<?\n, rest::binary>>,
           %State{mode: [mode | _], path: [unquote_splicing(closing_match) | _]} = state
         )
         when mode == unquote(mode) do
      do_parse(rest, state |> push_char(?\n) |> push_mode({:linefeed, 0}))
    end

    defp do_parse(
           <<x::utf8, rest::binary>>,
           %State{mode: [mode | _], path: [unquote_splicing(closing_match) | _]} = state
         )
         when mode == unquote(mode) do
      do_parse(rest, push_char(state, x))
    end
  end)

  # → :linefeed
  defp do_parse(<<?\n, rest::binary>>, state()) when is_raw(mode) do
    do_parse(rest, push_char(state, ?\n))
  end

  defp do_parse(<<?\n, rest::binary>>, state_linefeed()) do
    state =
      state
      |> listener(:break)
      |> rewind_state()
      |> set_mode({:linefeed, 0})

    do_parse(rest, state)
  end

  defp do_parse(<<?\n, rest::binary>>, state()) do
    state =
      case state.mode do
        [{:inner, {_, outer}, _} | _] -> rewind_state(state, until: outer, inclusive: true)
        _ -> state
      end

    state =
      state
      |> listener(:linefeed)
      |> push_char(?\n)
      |> push_mode({:linefeed, 0})

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

  defp do_parse(<<?\s, rest::binary>>, %State{mode: [{mode, _, _} | _]} = state)
       when mode in [:nested, :inner] do
    do_parse(rest, state)
  end

  Enum.each(@syntax[:pair], fn {md, properties} ->
    [tag | _] = tags = List.wrap(properties[:tag])
    closing = properties[:closing]
    outer = properties[:outer]
    inner_opening = properties[:inner_opening]
    inner_closing = properties[:inner_closing]
    inner_tag = Map.get(properties, :inner_tag, true)
    disclosure_opening = properties[:disclosure_opening]
    disclosure_closing = properties[:disclosure_closing]
    attrs = Macro.escape(properties[:attributes])

    defp do_parse(<<unquote(md), rest::binary>>, state()) when not is_raw(mode) do
      state =
        state
        |> listener({:tag, {unquote(md), unquote(tag)}, unquote(inner_tag)})
        |> replace_mode(:md)
        |> push_path(for tag <- unquote(tags), do: {tag, unquote(attrs), []})

      do_parse(rest, state)
    end

    defp do_parse(
           <<unquote(closing), unquote(inner_opening), rest::binary>>,
           %State{mode: [mode | _], path: [{unquote(tag), attrs, content} | path_tail]} = state
         )
         when not is_raw(mode) do
      do_parse(rest, %State{
        state
        | bag: %{state.bag | stock: content},
          path: [{unquote(tag), attrs, []} | path_tail]
      })
    end

    if not is_nil(disclosure_opening) do
      defp do_parse(
             <<unquote(closing), unquote(disclosure_opening), rest::binary>>,
             %State{mode: [mode | _], path: [{unquote(tag), attrs, content} | path_tail]} = state
           )
           when not is_raw(mode) do
        do_parse(rest, %State{
          state
          | bag: %{state.bag | stock: content},
            path: [{unquote(tag), attrs, []} | path_tail]
        })
      end
    end

    defp do_parse(
           <<unquote(inner_closing), rest::binary>>,
           %State{
             mode: [mode | _],
             bag: %{stock: outer_content},
             path: [{unquote(tag), attrs, [content]} | path_tail]
           } = state
         )
         when not is_raw(mode) do
      final_tag =
        case unquote(outer) do
          {:attribute, attribute} ->
            {unquote(tag), Map.put(attrs || %{}, attribute, content), outer_content}

          {:tag, {tag, attr}} ->
            {unquote(tag), attrs,
             [
               {unquote(inner_tag), %{attr => content}, []},
               {tag, nil, outer_content}
             ]}

          {:tag, tag} ->
            {unquote(tag), attrs,
             [
               {unquote(inner_tag), nil, [content]},
               {tag, nil, outer_content}
             ]}
        end

      state =
        %State{state | bag: %{state.bag | stock: []}, path: [final_tag | path_tail]}
        |> to_ast()
        |> replace_mode(:md)

      do_parse(rest, state)
    end

    if not is_nil(disclosure_closing) do
      defp do_parse(
             <<unquote(disclosure_closing), rest::binary>>,
             %State{
               mode: [mode | _],
               bag: %{stock: []},
               path: [{unquote(tag), _attrs, [content]} | path_tail]
             } = state
           )
           when not is_raw(mode) do
        content = unquote(disclosure_opening) <> content <> unquote(disclosure_closing)
        state = push_char(%State{state | path: path_tail}, content)
        do_parse(rest, state)
      end

      defp do_parse(
             <<unquote(disclosure_closing), rest::binary>>,
             %State{
               mode: [mode | _],
               bag: %{stock: outer_content},
               path: [{unquote(tag), attrs, [content]} | path_tail]
             } = state
           )
           when not is_raw(mode) do
        content = unquote(disclosure_opening) <> content <> unquote(disclosure_closing)

        final_tag =
          case unquote(outer) do
            {:attribute, attr} ->
              attributes =
                Map.put(attrs || %{}, :__deferred__, %{
                  kind: :attribute,
                  attribute: attr,
                  content: content
                })

              {unquote(tag), attributes, outer_content}

            {:tag, {tag, attr}} ->
              attributes =
                Map.put(attrs || %{}, :__deferred__, %{
                  kind: :attribute,
                  attribute: attr,
                  content: content
                })

              {unquote(tag), attrs,
               [{unquote(inner_tag), attributes, []}, {tag, nil, outer_content}]}

            {:tag, tag} ->
              attributes = Map.put(attrs || %{}, :__deferred__, %{kind: :text, content: content})

              {unquote(tag), attrs,
               [
                 {unquote(inner_tag), attributes, []},
                 {tag, nil, outer_content}
               ]}
          end

        bag =
          state.bag
          |> Map.put(:stock, [])
          |> Map.update!(:deferred, &[content | &1])

        state =
          %State{state | bag: bag, path: [final_tag | path_tail]}
          |> to_ast()
          |> replace_mode(:md)

        do_parse(rest, state)
      end
    end
  end)

  Enum.each(@syntax[:paragraph], fn {md, properties} ->
    [tag | _] = tags = List.wrap(properties[:tag])
    mode = Macro.escape(Map.get(properties, :mode, {:nested, tag, 1}))
    attrs = Macro.escape(properties[:attributes])

    closing_match = closing_match(tags)

    defp do_parse(<<unquote(md), rest::binary>>, empty({:linefeed, _pos})) do
      state =
        state
        |> listener({:tag, {unquote(md), unquote(tag)}, true})
        |> replace_mode(unquote(mode))
        |> push_path(for tag <- unquote(tags), do: {tag, unquote(attrs), []})

      do_parse(rest, state)
    end

    defp do_parse(
           <<unquote(md), rest::binary>>,
           %State{mode: [mode | _], path: [unquote_splicing(closing_match) | _]} = state
         )
         when not is_raw(mode) do
      current_level = level(state, unquote(tag))

      case mode do
        {:linefeed, pos} ->
          # [AM] state = pop_mode(state)
          state =
            state
            |> pop_mode([{:linefeed, pos}, {:nested, unquote(tag), 1}, :md])
            |> push_mode({:nested, unquote(tag), 1})

          do_parse(rest, state)

        {:nested, unquote(tag), level} when level < current_level ->
          state = replace_mode(state, {:nested, unquote(tag), level + 1})
          do_parse(rest, state)

        {:nested, unquote(tag), level} ->
          state =
            state
            |> listener({:tag, {unquote(md), unquote(tag)}, true})
            |> replace_mode({:nested, unquote(tag), level + 1})
            |> push_path(for tag <- unquote(tags), do: {tag, unquote(attrs), []})

          do_parse(rest, state)
      end
    end

    defp do_parse(
           <<unquote(md), rest::binary>>,
           %State{mode: [{:nested, _, _} = nested, {:inner, :raw} | modes]} = state
         ) do
      state = %State{state | mode: [{:linefeed, 0}, {:inner, :raw}, nested | modes]}

      do_parse(rest, state)
    end

    defp do_parse(
           <<unquote(md), rest::binary>>,
           %State{mode: [{:nested, _, _} | _]} = state
         ) do
      state =
        state
        |> listener({:tag, {unquote(md), unquote(tag)}, true})
        |> push_path(for tag <- unquote(tags), do: {tag, unquote(attrs), []})

      do_parse(rest, state)
    end

    defp do_parse(<<unquote(md), rest::binary>>, state_linefeed()) do
      state = pop_mode(state, [{:linefeed, pos}, :md])

      case state do
        %State{mode: [{:inner, {_, _}, _} | _]} ->
          state = %State{state | bag: %{state.bag | indent: [pos | state.bag.indent]}}
          do_parse(rest, state)

        %State{mode: [{:nested, tag, _} | _]} ->
          state = rewind_state(state, until: tag, inclusive: false)
          do_parse(rest, state)
      end
    end
  end)

  Enum.each(@syntax[:list], fn {md, properties} ->
    [tag | _] = tags = List.wrap(properties[:tag])
    outer = Map.get(properties, :outer, :ul)
    attrs = Macro.escape(properties[:attributes])

    defp do_parse(<<unquote(md), rest::binary>>, empty({:linefeed, pos})) do
      state =
        state
        |> listener({:tag, {unquote(md), unquote(outer)}, true})
        |> listener({:tag, {unquote(md), unquote(tag)}, true})
        |> replace_mode({:inner, {unquote(tag), unquote(outer)}, pos})
        |> push_path(for tag <- [unquote(outer) | unquote(tags)], do: {tag, unquote(attrs), []})

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
         when not is_raw(mode) do
      case mode do
        {:linefeed, pos} ->
          state =
            state
            |> rewind_state(until: unquote(tag))
            |> replace_mode({:inner, {unquote(tag), unquote(outer)}, pos})

          do_parse(input, state)

        {:inner, {unquote(tag), unquote(outer)}, ^indent} ->
          state =
            state
            |> rewind_state(until: unquote(outer))
            |> listener({:tag, {unquote(md), unquote(tag)}, true})
            |> push_path({unquote(tag), unquote(attrs), []})

          do_parse(rest, state)

        {:inner, {unquote(tag), unquote(outer)}, pos} when pos > indent ->
          state =
            state
            |> rewind_state(until: unquote(outer))
            |> listener({:tag, {unquote(md), unquote(outer)}, true})
            |> listener({:tag, {unquote(md), unquote(tag)}, true})
            |> push_path([
              {unquote(outer), unquote(attrs), []},
              {unquote(tag), unquote(attrs), []}
            ])

          do_parse(rest, %State{state | bag: %{state.bag | indent: [pos | indents]}})

        {:inner, {unquote(tag), unquote(outer)}, pos} when pos < indent ->
          {skipped, indents} = Enum.split_with(indents, &(&1 > pos))

          state =
            state
            |> rewind_state(
              until: unquote(outer),
              count: Enum.count(skipped),
              inclusive: true
            )
            |> listener({:tag, {unquote(md), unquote(tag)}, true})
            |> push_path({unquote(tag), unquote(attrs), []})

          do_parse(rest, %State{state | bag: %{state.bag | indent: indents}})
      end
    end

    defp do_parse(
           <<unquote(md), rest::binary>>,
           %State{mode: [{:nested, _tag, _level} | _], bag: %{indent: indents}} = state
         ) do
      indent =
        case indents do
          [indent | _] -> indent
          _ -> 0
        end

      state =
        state
        |> listener({:tag, {unquote(md), unquote(tag)}, true})
        |> push_mode({:inner, {unquote(tag), unquote(outer)}, indent})
        |> push_path([{unquote(outer), unquote(attrs), []}, {unquote(tag), unquote(attrs), []}])

      do_parse(rest, state)
    end

    defp do_parse(<<unquote(md), _::binary>> = input, state_linefeed()) do
      state = rewind_state(state, until: unquote(tag))
      do_parse(input, state)
    end
  end)

  Enum.each(@syntax[:brace], fn {md, properties} ->
    [tag | _] = tags = List.wrap(properties[:tag])
    mode = properties[:mode]
    attrs = Macro.escape(properties[:attributes])

    closing_match = closing_match(tags)

    defp do_parse(
           <<unquote(md), rest::binary>>,
           %State{mode: [mode | _], path: [unquote_splicing(closing_match) | _]} = state
         )
         when mode == unquote(mode) or not is_raw(mode) do
      state =
        state
        |> to_ast()
        |> pop_mode(unquote(mode))

      do_parse(rest, state)
    end

    defp do_parse(<<unquote(md), rest::binary>>, state()) when not is_raw(mode) do
      state =
        state
        |> listener({:tag, {unquote(md), unquote(tag)}, true})
        |> push_mode(unquote(mode))
        |> push_path(for tag <- unquote(tags), do: {tag, unquote(attrs), []})

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

    state =
      if is_raw(mode) or is_md(mode), do: state, else: state |> pop_mode([:md]) |> push_mode(:md)

    do_parse(rest, state)
  end

  defp do_parse("", state()) do
    state =
      state
      |> listener(:finalize)
      |> rewind_state()
      |> apply_deferreds()

    state = %State{state | mode: [:finished], bag: %{state.bag | indent: [], stock: []}}

    listener(state, :end)
  end

  @spec push_char(L.state(), pos_integer() | binary()) :: L.state()
  defp push_char(state, x) when is_integer(x),
    do: push_char(state, <<x::utf8>>)

  defp push_char(empty(_), <<?\n>>), do: state
  defp push_char(empty({:linefeed, _}), <<?\s>>), do: state

  defp push_char(empty({:linefeed, _}), x),
    do: %State{state | path: [{get_in(syntax(), [:settings, :outer]) || :article, nil, [x]}]}

  defp push_char(empty(_), x),
    do: %State{state | path: [{get_in(syntax(), [:settings, :span]) || :span, nil, [x]}]}

  defp push_char(state(), x) do
    path =
      case {x, mode, state.path} do
        {<<?\n>>, _, [{elem, attrs, branch} | rest]} ->
          [{elem, attrs, [x | branch]} | rest]

        {_, _, [{elem, attrs, [txt | branch]} | rest]} when is_binary(txt) and txt != <<?\n>> ->
          [{elem, attrs, [txt <> x | branch]} | rest]

        {_, _, [{elem, attrs, branch} | rest]} ->
          [{elem, attrs, [x | branch]} | rest]
      end

    %State{state | path: path}
  end

  ## helpers
  @spec listener(L.state(), L.context()) :: L.state()
  def listener(%State{listener: nil} = state, _), do: state

  def listener(%State{} = state, context) do
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
  defp push_mode(%State{mode: [mode | _]} = state, mode), do: state
  defp push_mode(%State{} = state, value), do: %State{state | mode: [value | state.mode]}

  # @dialyzer {:nowarn_function, pop_mode: 1, pop_mode: 2}
  # @spec pop_mode(L.state()) :: L.state()
  # defp pop_mode(state()), do: %State{state | mode: tl(state.mode)}

  @dialyzer {:nowarn_function, pop_mode: 2}
  @spec pop_mode(L.state(), L.element() | [L.element()]) :: L.state()
  defp pop_mode(state(), modes) when is_list(modes) do
    {_, modes} = Enum.split_while(state.mode, &(&1 in modes))
    %State{state | mode: modes}
  end

  defp pop_mode(state(), mode), do: %State{state | mode: tl(state.mode)}
  defp pop_mode(state(), _), do: state

  @spec push_path(L.state(), L.branch() | [L.branch()]) :: L.state()
  defp push_path(state(), elements) when is_list(elements),
    do: Enum.reduce(elements, state, &push_path(&2, &1))

  defp push_path(%State{path: path} = state, element),
    do: %State{state | path: [element | path]}

  @spec rewind_state(L.state(), [
          {:until, L.element()}
          | {:count, pos_integer()}
          | {:inclusive, boolean()}
          | {:pop, %{required(atom()) => atom()}}
        ]) :: L.state()
  defp rewind_state(state, params \\ []) do
    pop = Keyword.get(params, :pop, %{})
    until = Keyword.get(params, :until, nil)
    count = Keyword.get(params, :count, 1)
    inclusive = Keyword.get(params, :inclusive, false)

    for i <- 1..count, count > 0, reduce: state do
      acc ->
        state =
          Enum.reduce_while(acc.path, acc, fn
            {^until, _, _}, acc -> {:halt, acc}
            _, acc -> {:cont, to_ast(acc, pop)}
          end)

        if i < count or inclusive, do: to_ast(state, pop), else: state
    end
  end

  @spec apply_deferreds(L.state()) :: L.state()
  defp apply_deferreds(%State{bag: %{deferred: []}} = state), do: state

  defp apply_deferreds(%State{bag: %{deferred: deferreds}} = state) do
    deferreds =
      deferreds
      |> Enum.filter(&match?({_, _}, &1))
      |> Map.new()

    ast =
      Macro.prewalk(state.ast, fn
        {tag, %{__deferred__: %{attribute: attribute, content: mark, kind: :attribute}} = attrs,
         content} ->
          value = Map.get(deferreds, mark, content)

          attrs =
            attrs
            |> Map.delete(:__deferred__)
            |> Map.put(attribute, value)

          {tag, attrs, content}

        other ->
          other
      end)

    %State{state | ast: ast}
  end

  @spec update_attrs(L.branch(), %{required(atom()) => atom()}) :: L.branch()
  defp update_attrs({_, _, []} = tag, _), do: tag

  defp update_attrs({tag, attrs, [value | rest]} = full_tag, pop) do
    case pop do
      %{^tag => attr} -> {tag, Map.put(attrs || %{}, attr, value), rest}
      _ -> full_tag
    end
  end

  @spec to_ast(L.state(), %{required(atom()) => atom()}) :: L.state()
  defp to_ast(state, pop \\ %{})
  defp to_ast(%State{path: []} = state, _), do: state

  @empty_tags @syntax |> Keyword.get(:settings, []) |> Map.get(:empty_tags, [])
  defp to_ast(%State{path: [{tag, _, []} | rest]} = state, _) when tag not in @empty_tags,
    do: to_ast(%State{state | path: rest})

  defp to_ast(%State{path: [{tag, _, _} = last], ast: ast} = state, pop) do
    last =
      last
      |> reverse()
      |> update_attrs(pop)
      |> trim(false)

    state = %State{state | path: [], ast: [last | ast]}
    listener(state, {:tag, tag, false})
  end

  defp to_ast(%State{path: [{tag, _, _} = last, {elem, attrs, branch} | rest]} = state, pop) do
    last =
      last
      |> reverse()
      |> update_attrs(pop)
      |> trim(false)

    state = %State{state | path: [{elem, attrs, [last | branch]} | rest]}
    listener(state, {:tag, tag, false})
  end

  @spec reverse(L.trace()) :: L.trace()
  defp reverse({_, _, branch} = trace) when is_list(branch), do: trim(trace, true)

  @spec trim(L.trace(), boolean()) :: L.trace()
  defp trim(trace, reverse?)
  defp trim({elem, attrs, [<<?\n>> | rest]}, reverse?), do: trim({elem, attrs, rest}, reverse?)
  defp trim({elem, attrs, [<<?\s>> | rest]}, reverse?), do: trim({elem, attrs, rest}, reverse?)

  defp trim({elem, attrs, branch}, reverse?),
    do: if(reverse?, do: {elem, attrs, Enum.reverse(branch)}, else: {elem, attrs, branch})
end
