# ![Md Logo](https://github.com/am-kantox/md/raw/master/stuff/logo-48x48.png) [![Kantox ❤ OSS](https://img.shields.io/badge/❤-kantox_oss-informational.svg)](https://kantox.com/)  ![Test](https://github.com/am-kantox/md/workflows/Test/badge.svg)  ![Dialyzer](https://github.com/am-kantox/md/workflows/Dialyzer/badge.svg)

**Stream markup parser, extendable, flexible, blazingly fast, with callbacks and more, ready for markdown…**

---

## Main Focus

This library is not yet another markdown parser, rather it’s a highly configurable
and extendable parser for any custom markdown-like markup. It has been created
mostly to allow custom markdown syntax, like `^foo^` for superscript, or `⇓bar⇓`
for subscript. It also supports [custom parsers](https://hexdocs.pm/md/Md.Parser.html)
for anything that cannot be handled with generic parsers, inspired by markdown
(something more complex than standard markdown provides.)

The library provides callbacks for all the default syntax handlers, as well as for
custom handlers, allowing the on-fly modification of what’s currently being processed.

`Md` parses the incoming stream **once** and keeps the state, producing an AST
of the input document. It has an ability to recover from errors collecting them.

It currently does not support (and I frankly doubt it ever will)
lists with embedded quotes, and other contrived syntax. If one needs to perfectly
parse the common markdown, `Md` is probably not the correct choice.

But if one wants to easily extend syntax almost without limits, `Md` might be good.

## Markup Handling

There are several different syntax patterns recognizable by `Md`. Those are:

- `custom` — the custom parser implementing `Md.Parser` behavious would be called
- `substitute` — simple substitution, like `"<"` → `"&lt;"`
- `escape` — characters to be treated as is, not as a part of syntax
- `comment` — characters to be treated as a comment, discarded in the output
- `flush` — somewhat breaking a paragraph flow, like triple-dash
- `magnet` — the markup for a single work following the patters, like `#tag`
- `block` — the whole block of input treated distinguished, like triple-backtick
- `shift` — the same as `block`, but the opening marker should precede each line
  and `"\n"` is treated as the closing marker
- `pair` — the opening marker followed by closing marker, and a subsequent pair
  of opening and closing, like `![name](#anchor)`; the second element might
  be an internal shortcut to the deferred disclosure
- `disclosure` — the disclosure of elements previously declared as `pair` with
  `deferred` parameter provided
- `paragraph` — a header, blockquote, or such, followed by a paragraph flow break
- `list` — a list, like `- one\n-two`
- `tag` — allowed tags (e. g. `<sup>2</sup>`)
- `brace` — a most common markdown feature, like text decoration or such (e. g. `**bold**`)

## Syntax description

The syntax must be configured at compile time (because `parse/2` handlers are
generated in compile time.) It is a map, having `settings` key

```elixir
settings: %{
  outer: :p,
  span: :span,
  empty_tags: ~w|img hr br|a
}
```

and `key ⇒ list_of_tuples` key-values, providing a text markup representation
and its handling rules. Here is the excerpt from the default parser for `brace`s

```elixir
  brace: %{
    "*" => %{tag: :b},
    "_" => %{tag: :i},
    "**" => %{tag: :strong, attributes: %{class: "nota-bene"}},
    "__" => %{tag: :em},
    "~" => %{tag: :s},
    "~~" => %{tag: :del},
    "`" => %{tag: :code, mode: :raw, attributes: %{class: "code-inline"}}
  }
```

For more examples of what properties are allowed for each kind of handlers,
see the sources (ATM.)

## Predefined parsers

`Md` comes with a generic predefined parser `Md.Parser.Default`, which includes
all the markup currently supported by `Md`.

Custom parser definition would be usually based on `Md.Parser.Syntax.Void` syntax
as shown below

```elixir
defmodule MyParser do
  use Md.Parser

  alias Md.Parser.Syntax.Void

  @default_syntax Map.put(Void.syntax(), :settings, Void.settings())
  @syntax @default_syntax |> Map.merge(%{
    comment: [{"<!--", %{closing: "-->"}}],
    paragraph: [
      {"##", %{tag: :h2}},
      {"###", %{tag: :h3}},
      {">", %{tag: :blockquote}}
    ],
    list:
      [
        {"- ", %{tag: :li, outer: :ul}},
        {"+ ", %{tag: :li, outer: :ol}}
      ]
    brace: [
      {"*", %{tag: :b}},
      {"_", %{tag: :i}},
      {"~", %{tag: :s}},
      {"`", %{tag: :code, mode: :raw, attributes: %{class: "code-inline"}}}
    ]
  })
end
```

`@syntax` module attribute must be declared, or DSL used as shown below
(declarations), or an argument in a call to `use Md.Parser`.
The separate declarations will be collected and merged.

```elixir
defmodule MyDSLParser do
  @my_syntax %{brace: [{"***", %{tag: "u"}}]}
  
  use Md.Parser, syntax: @my_syntax
  import Md.Parser.DSL

  comment "<!--", %{closing: "-->"}
  ...
end
```

Instead of `@syntax` module attribute, one might use

- a parameter to `use Md.Parser` as `use Md.Parser, syntax: map()`
- a DSL like `paragraph {"#", %{tag: :h1}}`.

---

## Changelog

- **`0.6.8`** `xml_builder`→`xml_builder_ex` (default formatting for code is now `:none`)
- **`0.6.0`** allow HTML tags (without attributes yet)
- **`0.5.0`** DSL + `use Md.Parser, syntax: …`  for configurable syntax
- **`0.4.0`** configurable syntax as `@syntax`
- **`0.3.0`** relaxed support for comments and tables
- **`0.2.1`** deferred references like in `[link][1]` followed by `[1]: https://example.com` somewhere
- **`0.2.0`** PoC, most of reasonable markdown is supported

## Installation

```elixir
def deps do
  [
    {:md, "~> 0.1"}
  ]
end
```

## [Documentation](https://hexdocs.pm/md)
