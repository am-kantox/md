defmodule Md.Parser.Default do
  @moduledoc false

  use Md.Parser

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
end
