defmodule Md.Engine do
  @moduledoc false

  @spec closing_match(Md.Listener.branch()) :: Macro.t()
  def closing_match(tags) do
    us = Macro.var(:_, %Macro.Env{}.context)
    Enum.reduce(tags, [], &[{:{}, [], [&1, us, us]} | &2])
  end

  defmacro __before_compile__(_env) do
    quote generated: true, location: :keep, context: __CALLER__.module do
      Md.Engine.macros()
      Md.Engine.init()
      Md.Engine.skip()
      Md.Engine.escape(@syntax[:escape])
      Md.Engine.comment(@syntax[:comment])
      Md.Engine.matrix(@syntax[:matrix])

      Md.Engine.disclosure(
        @syntax[:disclosure],
        Map.get(@syntax[:settings], :disclosure_range, 3..5)
      )

      Md.Engine.magnet(@syntax[:magnet])
      Md.Engine.custom(@syntax[:custom])
      Md.Engine.substitute(@syntax[:substitute])
      Md.Engine.flush(@syntax[:flush])
      Md.Engine.block(@syntax[:block])
      Md.Engine.shift(@syntax[:shift])
      Md.Engine.linefeed()
      Md.Engine.linefeed_mode()
      Md.Engine.pair(@syntax[:pair])
      Md.Engine.paragraph(@syntax[:paragraph])
      Md.Engine.list(@syntax[:list])
      Md.Engine.brace(@syntax[:brace])
      Md.Engine.plain()
      Md.Engine.terminate()
      Md.Engine.helpers()
    end
  end

  defmacro init do
    quote generated: true, location: :keep, context: __CALLER__.module do
      @spec do_parse(binary(), Md.Listener.state()) :: Md.Listener.state()
      defp do_parse(input, state)

      defp do_parse(input, initial()) do
        state =
          state
          |> listener(:start)
          |> set_mode({:linefeed, 0})

        do_parse(input, state)
      end
    end
  end

  defmacro skip do
    quote generated: true, location: :keep, context: __CALLER__.module do
      defp do_parse(<<?\n, input::binary>>, state(:skip)) do
        state = state |> pop_mode(:skip) |> push_mode({:linefeed, 0})
        do_parse(input, state)
      end

      defp do_parse(<<_::utf8, input::binary>>, state(:skip)) do
        do_parse(input, state)
      end
    end
  end

  defmacro escape(escapes) do
    quote generated: true,
          location: :keep,
          bind_quoted: [escapes: escapes],
          context: __CALLER__.module do
      Enum.each(escapes, fn {md, _} ->
        defp do_parse(unquote(md) <> <<x::utf8, rest::binary>>, state())
             when mode not in [:raw, {:inner, :raw}] do
          state =
            state
            |> listener({:esc, <<x::utf8>>})
            |> push_char(x)

          do_parse(rest, state)
        end
      end)
    end
  end

  defmacro comment(comments) do
    quote generated: true,
          location: :keep,
          bind_quoted: [comments: comments],
          context: __CALLER__.module do
      Enum.each(comments, fn {md, properties} ->
        closing = Map.get(properties, :closing, md)
        _tag = Map.get(properties, :tag, :comment)

        defp do_parse(unquote(md) <> rest, state()) when mode not in [:raw, {:inner, :raw}] do
          state =
            %Md.Parser.State{state | bag: %{state.bag | stock: [""]}}
            |> push_mode(:comment)

          do_parse(rest, state)
        end

        defp do_parse(unquote(closing) <> rest, state()) when mode == :comment do
          state =
            state
            |> listener({:comment, state.bag.stock})
            |> pop_mode(:comment)

          do_parse(rest, state)
        end

        defp do_parse(<<x::utf8, rest::binary>>, state()) when mode == :comment do
          [stock] = state.bag.stock
          state = %Md.Parser.State{state | bag: %{state.bag | stock: [stock <> <<x::utf8>>]}}
          do_parse(rest, state)
        end
      end)
    end
  end

  defmacro matrix(matrices) do
    quote generated: true,
          location: :keep,
          bind_quoted: [matrices: matrices],
          context: __CALLER__.module do
      Enum.each(@syntax[:matrix], fn {md, properties} ->
        skip = Map.get(properties, :skip)
        outer = Map.get(properties, :outer, md)
        inner = Map.get(properties, :inner, outer)
        [tag | _] = tags = properties |> Map.get(:tag, :div) |> List.wrap()
        first_inner_tag = Map.get(properties, :first_inner_tag, tag)
        attrs = Macro.escape(properties[:attributes])

        if not is_nil(skip) do
          defp do_parse(<<unquote(skip), rest::binary>>, state_linefeed()) do
            state =
              state
              |> pop_mode([{:linefeed, pos}, :md])
              |> push_mode(:skip)

            do_parse(rest, state)
          end
        end

        defp do_parse(
               <<unquote(md), rest::binary>>,
               %Md.Parser.State{
                 mode: [{:linefeed, pos} | _],
                 path: [{tag, _, _} | _]
               } = state
             )
             when tag in [unquote(first_inner_tag), unquote_splicing(tags)] do
          state =
            state
            |> pop_mode([{:linefeed, pos}, :md])
            |> rewind_state(until: unquote(inner), inclusive: true, trim: true)
            |> push_path({unquote(inner), nil, []})
            |> push_path({unquote(tag), nil, []})
            |> push_mode(:md)

          do_parse(rest, state)
        end

        defp do_parse(
               <<unquote(md), rest::binary>>,
               %Md.Parser.State{path: [{tag, _, _} | _]} = state
             )
             when tag in [unquote(first_inner_tag), unquote_splicing(tags)] do
          state =
            state
            |> to_ast()
            |> push_path({tag, nil, []})

          do_parse(rest, state)
        end

        defp do_parse(<<unquote(md), rest::binary>>, state_linefeed()) do
          state =
            state
            |> pop_mode([{:linefeed, pos}, :md])
            |> listener({:tag, {unquote(md), unquote(outer)}, true})
            |> listener({:tag, {unquote(md), unquote(first_inner_tag)}, true})
            |> push_path({unquote(outer), unquote(attrs), []})
            |> push_path({unquote(inner), nil, []})
            |> push_path({unquote(first_inner_tag), nil, []})
            |> push_mode(:md)

          do_parse(rest, state)
        end
      end)
    end
  end

  defmacro disclosure(disclosures, disclosure_range) do
    quote generated: true,
          location: :keep,
          bind_quoted: [disclosures: disclosures, disclosure_range: disclosure_range],
          context: __CALLER__.module do
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
                 %Md.Parser.State{
                   mode: [{:linefeed, pos} | _],
                   bag: %{deferred: deferreds}
                 } = state
               )
               when length(deferreds) > 0 do
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
               %Md.Parser.State{
                 mode: [mode | _],
                 path: [{:__deferred__, disclosure, [content]} | path]
               } = state
             )
             when mode in [:raw, {:inner, :raw}] do
          deferred = [{disclosure, content} | state.bag.deferred]

          state =
            %Md.Parser.State{state | bag: Map.put(state.bag, :deferred, deferred), path: path}
            |> replace_mode({:linefeed, 0})

          do_parse(rest, state)
        end
      end)
    end
  end

  defmacro magnet(magnets) do
    quote generated: true,
          location: :keep,
          bind_quoted: [magnets: magnets],
          context: __CALLER__.module do
      Enum.each(magnets, fn {md, properties} ->
        transform =
          properties[:transform]
          |> case do
            f when is_function(f, 2) -> f
            m when is_atom(m) -> &m.apply/2
          end
          |> Macro.escape()

        terminators = Map.get(properties, :terminators, [?\s, ?\n])
        greedy = Map.get(properties, :greedy, false)

        defp do_parse(unquote(md) <> rest, state()) when mode not in [:raw, {:inner, :raw}] do
          state =
            %Md.Parser.State{state | bag: %{state.bag | stock: ["", unquote(md)]}}
            |> push_mode(:magnet)

          do_parse(rest, state)
        end

        defp do_parse(
               <<x::utf8, delim, rest::binary>>,
               %Md.Parser.State{
                 bag: %{stock: [stock, unquote(md)]},
                 mode: [mode | _]
               } = state
             )
             when mode == :magnet and delim in unquote(terminators) do
          {pre, post, delim} =
            if unquote(greedy), do: {unquote(md), <<delim>>, ""}, else: {"", "", <<delim>>}

          {stock, rest} =
            case x do
              x when x != ?_ and x not in ?0..?9 and x not in ?a..?z and x not in ?A..?Z ->
                {pre <> stock <> post, <<x>> <> delim <> rest}

              _ ->
                {pre <> stock <> <<x>> <> post, delim <> rest}
            end

          transformed = unquote(transform).(unquote(md), stock)

          state =
            %Md.Parser.State{
              state
              | bag: %{state.bag | deferred: [stock | state.bag.deferred], stock: []}
            }
            |> push_path(transformed)
            |> to_ast()
            |> listener({:tag, {unquote(md), :magnet}, nil})
            |> pop_mode(:magnet)

          do_parse(rest, state)
        end
      end)

      defp do_parse(<<x::utf8, rest::binary>>, state(:magnet)) do
        [stock, md] = state.bag.stock

        state = %Md.Parser.State{state | bag: %{state.bag | stock: [stock <> <<x::utf8>>, md]}}

        do_parse(rest, state)
      end
    end
  end

  defmacro custom(customs) do
    quote generated: true,
          location: :keep,
          bind_quoted: [customs: customs],
          context: __CALLER__.module do
      Enum.each(customs, fn
        {md, {handler, properties}} when is_atom(handler) or is_function(handler, 2) ->
          rewind = Map.get(properties, :rewind, false)

          defp do_parse(<<unquote(md), rest::binary>>, state())
               when mode not in [:raw, {:inner, :raw}] do
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
    end
  end

  defmacro substitute(substitutes) do
    quote generated: true,
          location: :keep,
          bind_quoted: [substitutes: substitutes],
          context: __CALLER__.module do
      Enum.each(substitutes, fn {md, properties} ->
        text = Map.get(properties, :text, "")

        defp do_parse(<<unquote(md), rest::binary>>, state())
             when mode not in [:raw, {:inner, :raw}] do
          state =
            state
            |> listener({:substitute, unquote(md), unquote(text)})
            |> push_char(unquote(text))

          do_parse(rest, state)
        end
      end)
    end
  end

  defmacro flush(flushes) do
    quote generated: true,
          location: :keep,
          bind_quoted: [flushes: flushes],
          context: __CALLER__.module do
      Enum.each(flushes, fn {md, properties} ->
        rewind = Map.get(properties, :rewind, false)
        [tag | _] = tags = List.wrap(properties[:tag])
        attrs = Macro.escape(properties[:attributes])

        defp do_parse(<<unquote(md), rest::binary>>, state())
             when mode not in [:raw, {:inner, :raw}] do
          state =
            unquote(rewind)
            |> if(do: rewind_state(state), else: state)
            |> push_path(for tag <- unquote(tags), do: {tag, unquote(attrs), []})
            |> listener({:tag, {unquote(md), unquote(tag)}, nil})
            |> rewind_state(until: unquote(tag), inclusive: true)
            |> set_mode({:linefeed, 0})

          do_parse(rest, state)
        end
      end)
    end
  end

  defmacro block(blocks) do
    quote generated: true,
          location: :keep,
          bind_quoted: [blocks: blocks],
          context: __CALLER__.module do
      Enum.each(blocks, fn {md, properties} ->
        [tag | _] = tags = List.wrap(properties[:tag])
        mode = properties[:mode]
        attrs = Macro.escape(properties[:attributes])
        pop = Macro.escape(properties[:pop])

        closing_match = Md.Engine.closing_match(tags)

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
               %Md.Parser.State{path: [unquote_splicing(closing_match) | _]} = state
             ) do
          state =
            state
            |> rewind_state(pop: unquote(pop))
            |> pop_mode(unquote(mode))
            |> push_mode(:md)

          do_parse(rest, state)
        end
      end)
    end
  end

  defmacro shift(shifts) do
    quote generated: true,
          location: :keep,
          bind_quoted: [shifts: shifts],
          context: __CALLER__.module do
      Enum.each(shifts, fn {md, properties} ->
        [tag | _] = tags = List.wrap(properties[:tag])
        mode = properties[:mode]
        attrs = Macro.escape(properties[:attributes])

        closing_match = Md.Engine.closing_match(tags)

        defp do_parse(
               <<unquote(md), rest::binary>>,
               %Md.Parser.State{
                 mode: [{:linefeed, 0} | _],
                 path: [unquote_splicing(closing_match) | _]
               } = state
             ) do
          state =
            state
            |> pop_mode({:linefeed, 0})
            |> push_mode(unquote(mode))

          do_parse(rest, state)
        end

        defp do_parse(
               <<unquote(md), rest::binary>>,
               %Md.Parser.State{
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
               %Md.Parser.State{
                 mode: [{:linefeed, 0}, unquote(mode), {:nested, _, _} = nested | modes],
                 path: [unquote_splicing(closing_match) | _]
               } = state
             ) do
          state = %Md.Parser.State{state | mode: [nested, unquote(mode) | modes]}

          do_parse(input, state)
        end

        defp do_parse(
               input,
               %Md.Parser.State{
                 mode: [{:linefeed, 0} | _],
                 path: [unquote_splicing(closing_match) | _]
               } = state
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
               %Md.Parser.State{mode: [mode | _], path: [unquote_splicing(closing_match) | _]} =
                 state
             )
             when mode == unquote(mode) do
          do_parse(rest, state |> push_char(?\n) |> push_mode({:linefeed, 0}))
        end

        defp do_parse(
               <<x::utf8, rest::binary>>,
               %Md.Parser.State{mode: [mode | _], path: [unquote_splicing(closing_match) | _]} =
                 state
             )
             when mode == unquote(mode) do
          do_parse(rest, push_char(state, x))
        end
      end)
    end
  end

  defmacro linefeed do
    quote generated: true,
          location: :keep,
          context: __CALLER__.module do
      defp do_parse(<<?\n, rest::binary>>, state()) when mode in [:raw, {:inner, :raw}] do
        do_parse(rest, push_char(state, ?\n))
      end

      defp do_parse(<<?\n, rest::binary>>, state_linefeed()) do
        state =
          state
          |> listener(:break)
          |> rewind_state(trim: true)
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
    end
  end

  defmacro linefeed_mode do
    quote generated: true,
          location: :keep,
          context: __CALLER__.module do
      defp do_parse(<<?\s, rest::binary>>, state_linefeed()) do
        state =
          state
          |> listener(:whitespace)
          |> replace_mode({:linefeed, pos + 1})

        do_parse(rest, state)
      end

      defp do_parse(<<?\s, rest::binary>>, %Md.Parser.State{mode: [{mode, _, _} | _]} = state)
           when mode in [:nested, :inner] do
        do_parse(rest, state)
      end
    end
  end

  defmacro pair(pairs) do
    quote generated: true,
          location: :keep,
          bind_quoted: [pairs: pairs],
          context: __CALLER__.module do
      Enum.each(pairs, fn {md, properties} ->
        [tag | _] = tags = List.wrap(properties[:tag])
        closing = properties[:closing]
        outer = properties[:outer]
        inner_opening = properties[:inner_opening]
        inner_closing = properties[:inner_closing]
        inner_tag = Map.get(properties, :inner_tag, true)
        disclosure_opening = properties[:disclosure_opening]
        disclosure_closing = properties[:disclosure_closing]
        attrs = Macro.escape(properties[:attributes])

        defp do_parse(<<unquote(md), rest::binary>>, state())
             when mode not in [:raw, {:inner, :raw}] do
          state =
            state
            |> listener({:tag, {unquote(md), unquote(tag)}, unquote(inner_tag)})
            |> replace_mode(:md)
            |> push_path(for tag <- unquote(tags), do: {tag, unquote(attrs), []})

          do_parse(rest, state)
        end

        defp do_parse(
               <<unquote(closing), unquote(inner_opening), rest::binary>>,
               %Md.Parser.State{
                 mode: [mode | _],
                 path: [{unquote(tag), attrs, content} | path_tail]
               } = state
             )
             when mode not in [:raw, {:inner, :raw}] do
          do_parse(rest, %Md.Parser.State{
            state
            | bag: %{state.bag | stock: content},
              path: [{unquote(tag), attrs, []} | path_tail]
          })
        end

        if not is_nil(disclosure_opening) do
          defp do_parse(
                 <<unquote(closing), unquote(disclosure_opening), rest::binary>>,
                 %Md.Parser.State{
                   mode: [mode | _],
                   path: [{unquote(tag), attrs, content} | path_tail]
                 } = state
               )
               when mode not in [:raw, {:inner, :raw}] do
            do_parse(rest, %Md.Parser.State{
              state
              | bag: %{state.bag | stock: content},
                path: [{unquote(tag), attrs, []} | path_tail]
            })
          end
        end

        defp do_parse(
               <<unquote(inner_closing), rest::binary>>,
               %Md.Parser.State{
                 mode: [mode | _],
                 bag: %{stock: outer_content},
                 path: [{unquote(tag), attrs, [content]} | path_tail]
               } = state
             )
             when mode not in [:raw, {:inner, :raw}] do
          final_tag =
            case unquote(outer) do
              {:attribute, {attr_content, attr_outer_content}} ->
                attrs =
                  attrs
                  |> Kernel.||(%{})
                  |> Map.put(attr_content, content)
                  |> Map.put(attr_outer_content, List.first(outer_content))

                {unquote(tag), attrs, []}

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
            %Md.Parser.State{state | bag: %{state.bag | stock: []}, path: [final_tag | path_tail]}
            |> to_ast()
            |> replace_mode(:md)

          do_parse(rest, state)
        end

        if not is_nil(disclosure_closing) do
          defp do_parse(
                 <<unquote(disclosure_closing), rest::binary>>,
                 %Md.Parser.State{
                   mode: [mode | _],
                   bag: %{stock: []},
                   path: [{unquote(tag), _attrs, [content]} | path_tail]
                 } = state
               )
               when mode not in [:raw, {:inner, :raw}] do
            content = unquote(disclosure_opening) <> content <> unquote(disclosure_closing)
            state = push_char(%Md.Parser.State{state | path: path_tail}, content)
            do_parse(rest, state)
          end

          defp do_parse(
                 <<unquote(disclosure_closing), rest::binary>>,
                 %Md.Parser.State{
                   mode: [mode | _],
                   bag: %{stock: outer_content},
                   path: [{unquote(tag), attrs, [content]} | path_tail]
                 } = state
               )
               when mode not in [:raw, {:inner, :raw}] do
            content = unquote(disclosure_opening) <> content <> unquote(disclosure_closing)

            final_tag =
              case unquote(outer) do
                {:attribute, {attr_content, attr_outer_content}} ->
                  attributes =
                    attrs
                    |> Kernel.||(%{})
                    |> Map.put(:__deferred__, %{
                      kind: :attribute,
                      attribute: attr_content,
                      content: content,
                      outer_attribute: attr_outer_content,
                      outer_content: outer_content
                    })

                  {unquote(tag), attributes, []}

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
                  attributes =
                    Map.put(attrs || %{}, :__deferred__, %{kind: :text, content: content})

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
              %Md.Parser.State{state | bag: bag, path: [final_tag | path_tail]}
              |> to_ast()
              |> replace_mode(:md)

            do_parse(rest, state)
          end
        end
      end)
    end
  end

  defmacro paragraph(paragraphs) do
    quote generated: true,
          location: :keep,
          bind_quoted: [paragraphs: paragraphs],
          context: __CALLER__.module do
      Enum.each(paragraphs, fn {md, properties} ->
        [tag | _] = tags = List.wrap(properties[:tag])
        mode = Macro.escape(Map.get(properties, :mode, {:nested, tag, 1}))
        attrs = Macro.escape(properties[:attributes])

        closing_match = Md.Engine.closing_match(tags)

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
               %Md.Parser.State{mode: [mode | _], path: [unquote_splicing(closing_match) | _]} =
                 state
             )
             when mode not in [:raw, {:inner, :raw}] do
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
               %Md.Parser.State{mode: [{:nested, _, _} = nested, {:inner, :raw} | modes]} = state
             ) do
          state = %Md.Parser.State{state | mode: [{:linefeed, 0}, {:inner, :raw}, nested | modes]}

          do_parse(rest, state)
        end

        defp do_parse(
               <<unquote(md), rest::binary>>,
               %Md.Parser.State{mode: [{:nested, _, _} | _]} = state
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
            %Md.Parser.State{mode: [{:inner, {_, _}, _} | _]} ->
              state = %Md.Parser.State{
                state
                | bag: %{state.bag | indent: [pos | state.bag.indent]}
              }

              do_parse(rest, state)

            %Md.Parser.State{mode: [{:nested, tag, _} | _]} ->
              state = rewind_state(state, until: tag, inclusive: false)
              do_parse(rest, state)
          end
        end
      end)
    end
  end

  defmacro list(lists) do
    quote generated: true,
          location: :keep,
          bind_quoted: [lists: lists],
          context: __CALLER__.module do
      Enum.each(lists, fn {md, properties} ->
        [tag | _] = tags = List.wrap(properties[:tag])
        outer = Map.get(properties, :outer, :ul)
        attrs = Macro.escape(properties[:attributes])

        defp do_parse(
               <<unquote(md), rest::binary>>,
               %Md.Parser.State{mode: [{:linefeed, pos} | _], path: []} = state
             ) do
          state =
            state
            |> listener({:tag, {unquote(md), unquote(outer)}, true})
            |> listener({:tag, {unquote(md), unquote(tag)}, true})
            |> replace_mode({:inner, {unquote(tag), unquote(outer)}, pos})
            |> push_path(
              for tag <- [unquote(outer) | unquote(tags)], do: {tag, unquote(attrs), []}
            )

          do_parse(rest, %Md.Parser.State{state | bag: %{state.bag | indent: [pos]}})
        end

        defp do_parse(
               <<unquote(md), rest::binary>> = input,
               %Md.Parser.State{
                 mode: [mode | _],
                 path: [{unquote(tag), _, _} | _],
                 bag: %{indent: [indent | _] = indents}
               } = state
             )
             when mode not in [:raw, {:inner, :raw}] do
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

              do_parse(rest, %Md.Parser.State{state | bag: %{state.bag | indent: [pos | indents]}})

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

              do_parse(rest, %Md.Parser.State{state | bag: %{state.bag | indent: indents}})
          end
        end

        defp do_parse(
               <<unquote(md), rest::binary>>,
               %Md.Parser.State{mode: [{:nested, _tag, _level} | _], bag: %{indent: indents}} =
                 state
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
            |> push_path([
              {unquote(outer), unquote(attrs), []},
              {unquote(tag), unquote(attrs), []}
            ])

          do_parse(rest, state)
        end

        defp do_parse(<<unquote(md), _::binary>> = input, state_linefeed()) do
          state = rewind_state(state, until: unquote(tag))
          do_parse(input, state)
        end
      end)
    end
  end

  defmacro brace(braces) do
    quote generated: true,
          location: :keep,
          bind_quoted: [braces: braces],
          context: __CALLER__.module do
      Enum.each(braces, fn {md, properties} ->
        [tag | _] = tags = List.wrap(properties[:tag])
        mode = properties[:mode]
        attrs = Macro.escape(properties[:attributes])
        closing = Map.get(properties, :closing, md)
        closing_match = Md.Engine.closing_match(tags)

        defp do_parse(
               <<unquote(closing), rest::binary>>,
               %Md.Parser.State{mode: [mode | _], path: [unquote_splicing(closing_match) | _]} =
                 state
             )
             when mode == unquote(mode) or mode not in [:raw, {:inner, :raw}] do
          state =
            state
            |> to_ast()
            |> pop_mode(unquote(mode))

          do_parse(rest, state)
        end

        defp do_parse(<<unquote(md), rest::binary>>, state())
             when mode not in [:raw, {:inner, :raw}] do
          state =
            state
            |> listener({:tag, {unquote(md), unquote(tag)}, true})
            |> push_mode(unquote(mode))
            |> push_path(for tag <- unquote(tags), do: {tag, unquote(attrs), []})

          do_parse(rest, state)
        end
      end)
    end
  end

  defmacro plain do
    quote generated: true,
          location: :keep,
          context: __CALLER__.module do
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
          if mode in [:raw, {:inner, :raw}, :md],
            do: state,
            else: state |> pop_mode([:md]) |> push_mode(:md)

        do_parse(rest, state)
      end
    end
  end

  defmacro terminate do
    quote generated: true,
          location: :keep,
          context: __CALLER__.module do
      defp do_parse("", state()) do
        state =
          state
          |> listener(:finalize)
          |> rewind_state(trim: true)
          |> apply_deferreds()

        state = %Md.Parser.State{
          state
          | mode: [:finished],
            bag: %{state.bag | indent: [], stock: []}
        }

        listener(state, :end)
      end
    end
  end

  defmacro macros do
    quote generated: true, context: __CALLER__.module do
      # helper macros
      defmacrop initial do
        quote generated: true, context: __CALLER__.module do
          %Md.Parser.State{mode: [:idle], path: [], ast: []} = var!(state, __MODULE__)
        end
      end

      defmacrop empty(mode) do
        quote generated: true, context: __CALLER__.module do
          %Md.Parser.State{
            mode: [unquote(mode) = var!(mode, __MODULE__) | _],
            path: []
          } = var!(state, __MODULE__)
        end
      end

      defmacrop state do
        quote generated: true, context: __CALLER__.module do
          %Md.Parser.State{mode: [var!(mode, __MODULE__) | _]} = var!(state, __MODULE__)
        end
      end

      defmacrop state(mode) do
        quote generated: true, context: __CALLER__.module do
          %Md.Parser.State{mode: [unquote(mode) = var!(mode, __MODULE__) | _]} =
            var!(state, __MODULE__)
        end
      end

      defmacrop state_linefeed do
        quote generated: true, context: __CALLER__.module do
          %Md.Parser.State{mode: [{:linefeed, var!(pos, __MODULE__)} | _]} =
            var!(state, __MODULE__)
        end
      end

      @spec push_char(Md.Listener.state(), pos_integer() | binary()) :: Md.Listener.state()
      defp push_char(state, x) when is_integer(x),
        do: push_char(state, <<x::utf8>>)

      defp push_char(empty(_), <<?\n>>), do: state
      defp push_char(empty({:linefeed, _}), <<?\s>>), do: state

      defp push_char(empty({:linefeed, _}), x),
        do: %Md.Parser.State{
          state
          | path: [{get_in(syntax(), [:settings, :outer]) || :article, nil, [x]}]
        }

      defp push_char(empty(_), x),
        do: %Md.Parser.State{
          state
          | path: [{get_in(syntax(), [:settings, :span]) || :span, nil, [x]}]
        }

      defp push_char(state(), x) do
        path =
          case {x, mode, state.path} do
            {<<?\n>>, _, [{elem, attrs, branch} | rest]} ->
              [{elem, attrs, [x | branch]} | rest]

            {_, _, [{elem, attrs, [txt | branch]} | rest]}
            when is_binary(txt) and txt != <<?\n>> ->
              [{elem, attrs, [txt <> x | branch]} | rest]

            {_, _, [{elem, attrs, branch} | rest]} ->
              [{elem, attrs, [x | branch]} | rest]
          end

        %Md.Parser.State{state | path: path}
      end

      ## helpers
      @spec listener(Md.Listener.state(), Md.Listener.context()) :: Md.Listener.state()
      def listener(%Md.Parser.State{listener: nil} = state, _), do: state

      def listener(%Md.Parser.State{} = state, context) do
        case state.listener.element(context, state) do
          :ok -> state
          {:update, state} -> state
        end
      end

      @spec level(Md.Listener.state(), Md.Listener.element()) :: non_neg_integer()
      defp level(state(), tag),
        do: Enum.count(state.path, &match?({^tag, _, _}, &1))

      @spec set_mode(Md.Listener.state(), Md.Listener.parse_mode()) :: Md.Listener.state()
      defp set_mode(state(), value), do: %Md.Parser.State{state | mode: [value]}

      @spec replace_mode(Md.Listener.state(), Md.Listener.parse_mode() | nil) ::
              Md.Listener.state()
      defp replace_mode(state(), nil), do: state

      defp replace_mode(%Md.Parser.State{mode: [_ | modes]} = state, value),
        do: %Md.Parser.State{state | mode: [value | modes]}

      @spec push_mode(Md.Listener.state(), Md.Listener.parse_mode()) :: Md.Listener.state()
      defp push_mode(state(), nil), do: state
      defp push_mode(%Md.Parser.State{mode: [mode | _]} = state, mode), do: state

      defp push_mode(%Md.Parser.State{} = state, value),
        do: %Md.Parser.State{state | mode: [value | state.mode]}

      # @dialyzer {:nowarn_function, pop_mode: 1, pop_mode: 2}
      # @spec pop_mode(Md.Listener.state()) :: Md.Listener.state()
      # defp pop_mode(state()), do: %Md.Parser.State{state | mode: tl(state.mode)}

      @dialyzer {:nowarn_function, pop_mode: 2}
      @spec pop_mode(Md.Listener.state(), Md.Listener.element() | [Md.Listener.element()]) ::
              Md.Listener.state()
      defp pop_mode(state(), modes) when is_list(modes) do
        {_, modes} = Enum.split_while(state.mode, &(&1 in modes))
        %Md.Parser.State{state | mode: modes}
      end

      defp pop_mode(state(), mode), do: %Md.Parser.State{state | mode: tl(state.mode)}
      defp pop_mode(state(), _), do: state

      @spec push_path(Md.Listener.state(), Md.Listener.branch() | [Md.Listener.branch()]) ::
              Md.Listener.state()
      defp push_path(state(), elements) when is_list(elements),
        do: Enum.reduce(elements, state, &push_path(&2, &1))

      defp push_path(%Md.Parser.State{path: path} = state, element),
        do: %Md.Parser.State{state | path: [element | path]}
    end
  end

  defmacro helpers do
    quote do
      @spec rewind_state(Md.Listener.state(), [
              {:until, Md.Listener.element()}
              | {:trim, boolean()}
              | {:count, pos_integer()}
              | {:inclusive, boolean()}
              | {:pop, %{required(atom()) => atom()}}
            ]) :: Md.Listener.state()
      defp rewind_state(state, params \\ []) do
        pop = Keyword.get(params, :pop, %{})
        until = Keyword.get(params, :until, nil)
        trim = Keyword.get(params, :trim, false)
        count = Keyword.get(params, :count, 1)
        inclusive = Keyword.get(params, :inclusive, false)

        for i <- 1..count, count > 0, reduce: state do
          acc ->
            state =
              acc.path
              |> Enum.reduce_while({trim, acc}, fn
                {^until, _, _}, acc ->
                  {:halt, acc}

                {_, _, content}, {true, acc} ->
                  if Enum.all?(content, &is_binary/1) and
                       content |> Enum.join() |> String.trim() == "",
                     do: {:cont, {true, %Md.Parser.State{acc | path: tl(acc.path)}}},
                     else: {:cont, {false, to_ast(acc, pop)}}

                _, {_, acc} ->
                  {:cont, {false, to_ast(acc, pop)}}
              end)
              |> elem(1)

            if i < count or inclusive, do: to_ast(state, pop), else: state
        end
      end

      @spec apply_deferreds(Md.Listener.state()) :: Md.Listener.state()
      defp apply_deferreds(%Md.Parser.State{bag: %{deferred: []}} = state), do: state

      defp apply_deferreds(%Md.Parser.State{bag: %{deferred: deferreds}} = state) do
        deferreds =
          deferreds
          |> Enum.filter(&match?({_, _}, &1))
          |> Map.new()

        ast =
          Macro.prewalk(state.ast, fn
            {tag,
             %{__deferred__: %{attribute: attribute, content: mark, kind: :attribute}} = attrs,
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

        %Md.Parser.State{state | ast: ast}
      end

      @spec update_attrs(Md.Listener.branch(), %{required(atom()) => atom()}) ::
              Md.Listener.branch()
      defp update_attrs({_, _, []} = tag, _), do: tag

      defp update_attrs({_tag, _attrs, [value | _rest]} = tag, _pop)
           when value in ["", "\n", "\s"],
           do: tag

      defp update_attrs({tag, attrs, [value | rest]} = full_tag, pop) do
        case pop do
          %{^tag => attr} -> {tag, Map.put(attrs || %{}, attr, value), rest}
          _ -> full_tag
        end
      end

      @spec to_ast(Md.Listener.state(), %{required(atom()) => atom()}) :: Md.Listener.state()
      defp to_ast(state, pop \\ %{})
      defp to_ast(%Md.Parser.State{path: []} = state, _), do: state

      @empty_tags @syntax |> Keyword.get(:settings, []) |> Map.get(:empty_tags, [])
      defp to_ast(%Md.Parser.State{path: [{tag, _, []} | rest]} = state, _)
           when tag not in @empty_tags,
           do: to_ast(%Md.Parser.State{state | path: rest})

      defp to_ast(%Md.Parser.State{path: [{tag, _, _} = last], ast: ast} = state, pop) do
        last =
          last
          |> reverse()
          |> update_attrs(pop)
          |> trim(false)

        state = %Md.Parser.State{state | path: [], ast: [last | ast]}
        listener(state, {:tag, tag, false})
      end

      defp to_ast(
             %Md.Parser.State{path: [{tag, _, _} = last, {elem, attrs, branch} | rest]} = state,
             pop
           ) do
        last =
          last
          |> reverse()
          |> update_attrs(pop)
          |> trim(false)

        state = %Md.Parser.State{state | path: [{elem, attrs, [last | branch]} | rest]}
        listener(state, {:tag, tag, false})
      end

      @spec reverse(Md.Listener.trace()) :: Md.Listener.trace()
      defp reverse({_, _, branch} = trace) when is_list(branch), do: trim(trace, true)

      @spec trim(Md.Listener.trace(), boolean()) :: Md.Listener.trace()
      defp trim(trace, reverse?)

      defp trim({elem, attrs, [<<?\n>> | rest]}, reverse?),
        do: trim({elem, attrs, rest}, reverse?)

      defp trim({elem, attrs, [<<?\s>> | rest]}, reverse?),
        do: trim({elem, attrs, rest}, reverse?)

      defp trim({elem, attrs, branch}, reverse?),
        do: if(reverse?, do: {elem, attrs, Enum.reverse(branch)}, else: {elem, attrs, branch})
    end
  end
end
