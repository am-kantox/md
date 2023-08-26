defmodule Md.Parser.Syntax.Default do
  @moduledoc false

  alias Md.Parser.{Syntax, Syntax.Void}
  alias Md.Transforms.{Anchor, Footnote, TwitterHandle}

  @behaviour Syntax

  @ol_max Application.compile_env(:md, :ol_max, 10)
  @disclosure_range 3..5

  @impl Syntax
  def settings,
    do: Void.settings() |> Map.put(:disclosure_range, @disclosure_range)

  @impl Syntax
  def syntax do
    %{
      custom: [
        # {md, {handler, properties}}
      ],
      substitute: [
        {"<", %{text: "&lt;"}},
        {"&", %{text: "&amp;"}}
      ],
      escape: [
        {<<92>>, %{}}
      ],
      comment: [
        {"<!--", %{closing: "-->"}}
      ],
      matrix: [
        {"|", %{tag: :td, outer: :table, inner: :tr, first_inner_tag: :th, skip: "|-"}}
      ],
      flush: [
        {"---", %{tag: :hr, rewind: :flip_flop}},
        {"  \n", %{tag: :br}},
        {"  \n", %{tag: :br}},
        {"  \r\n", %{tag: :br}},
        {"  \r\n", %{tag: :br}}
      ],
      magnet: [
        # {"⚓", %{transform: Anchor, terminators: []}},
        {"[^", %{transform: Footnote, terminators: [?\]], greedy: true}},
        {"@", %{transform: &TwitterHandle.apply/2, terminators: [?,, ?., ?!, ??, ?:, ?;]}},
        {"https://", %{transform: Anchor, terminators: [], greedy: :left}},
        {"http://", %{transform: Anchor, terminators: [], greedy: :left}}
      ],
      block: [
        {"```", %{tag: [:pre, :code], pop: %{code: :class}}}
      ],
      shift: [
        {"    ", %{tag: [:div, :code], attributes: %{class: "pre"}}}
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
        {"§1", %{tag: :h1}},
        {"##", %{tag: :h2}},
        {"§2", %{tag: :h2}},
        {"###", %{tag: :h3}},
        {"§3", %{tag: :h3}},
        {"####", %{tag: :h4}},
        {"§4", %{tag: :h4}},
        {"#####", %{tag: :h5}},
        {"§5", %{tag: :h5}},
        {"######", %{tag: :h6}},
        {"§6", %{tag: :h6}},
        # nested
        {">", %{tag: [:blockquote, :p]}}
      ],
      list:
        [
          {"- ", %{tag: :li, outer: :ul}},
          {"* ", %{tag: :li, outer: :ul}},
          {"• ", %{tag: :li, outer: :ul}},
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
      ],
      tag: [
        {"sup", %{}},
        {"dl", %{}},
        {"dt", %{}},
        {"dd", %{}}
      ]
    }
  end
end
