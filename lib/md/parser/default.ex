defmodule Md.Parser.Default do
  @moduledoc false

  import Md.Utils
  require Md.Engine

  alias Md.Listener, as: L
  alias Md.Parser.State

  @behaviour Md.Parser

  require Application

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
    matrix: [
      {"|", %{tag: :td, outer: :table, inner: :tr, first_inner_tag: :th, skip: "|-"}}
    ],
    flush: [
      {"---", %{tag: :hr, rewind: true}},
      {"  \n", %{tag: :br}},
      {"  \n", %{tag: :br}}
    ],
    magnet: [
      {"⚓", %{transform: Md.Transforms.Anchor}},
      {"[^", %{transform: Md.Transforms.Footnote, terminators: [?\]], greedy: true}},
      {"@", %{transform: &Md.Transforms.TwitterHandle.apply/2}}
    ],
    block: [
      {"```", %{tag: [:pre, :code], mode: :raw, pop: %{code: :class}}}
    ],
    shift: [
      {"    ", %{tag: [:div, :code], attributes: %{class: "pre"}, mode: {:inner, :raw}}}
    ],
    pair: [
      {"![",
       %{
         tag: :img,
         closing: "]",
         inner_opening: "(",
         inner_closing: ")",
         outer: {:attribute, {:src, :title}}
       }},
      {"!![",
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
      {"_", %{tag: :i}},
      {"**", %{tag: :strong, attributes: %{class: "red"}}},
      {"__", %{tag: :em}},
      {"~", %{tag: :s}},
      {"~~", %{tag: :del}},
      {"``", %{tag: :span, mode: :raw, attributes: %{class: "code-inline"}}},
      {"`", %{tag: :code, mode: :raw, attributes: %{class: "code-inline"}}},
      {"[^", %{closing: "]", tag: :b, mode: :raw}}
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
  def parse(input, state \\ %State{}) do
    %State{ast: ast, path: []} = state = do_parse(input, state)
    {"", %State{state | ast: Enum.reverse(ast)}}
  end

  @spec do_parse(binary(), L.state()) :: L.state()
  defp do_parse(input, state)

  Md.Engine.macros()
  Md.Engine.init()
  Md.Engine.skip()
  Md.Engine.escape(@syntax[:escape])
  Md.Engine.comment(@syntax[:comment])
  Md.Engine.matrix(@syntax[:matrix])

  Md.Engine.disclosure(
    @syntax[:disclosure],
    Map.get(@syntax[:settings], :disclosure_range, @disclosure_range)
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

  @spec rewind_state(L.state(), [
          {:until, L.element()}
          | {:trim, boolean()}
          | {:count, pos_integer()}
          | {:inclusive, boolean()}
          | {:pop, %{required(atom()) => atom()}}
        ]) :: L.state()
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
                 do: {:cont, {true, %State{acc | path: tl(acc.path)}}},
                 else: {:cont, {false, to_ast(acc, pop)}}

            _, {_, acc} ->
              {:cont, {false, to_ast(acc, pop)}}
          end)
          |> elem(1)

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

  defp update_attrs({_tag, _attrs, [value | _rest]} = tag, _pop) when value in ["", "\n", "\s"],
    do: tag

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
