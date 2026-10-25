# Md ![Md Logo](https://github.com/am-kantox/md/raw/master/stuff/logo-48x48.png) [![Kantox ❤ OSS](https://img.shields.io/badge/❤-kantox_oss-informational.svg)](https://kantox.com/)  ![Test](https://github.com/am-kantox/md/workflows/Test/badge.svg)  ![Dialyzer](https://github.com/am-kantox/md/workflows/Dialyzer/badge.svg)

**Stream markup parser, extendable, flexible, blazingly fast, with callbacks and more, ready for markdown…**

---

### Main Focus

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

### Security

`Md` renders markup written by authors, which makes two things worth knowing:

- **Inline attributes are filtered.** `{{class: "x"}}` attaches attributes to the
  preceding element, so it is the one place a document could inject HTML. Under
  the default `:safe` policy only a known-good set of attributes is kept (plus
  `data-*`/`aria-*`), URI attributes refuse executable schemes such as
  `javascript:`, and `on*` event handlers are refused under *every* policy. See
  the `:attribute_allowlist` setting in `stuff/handler-parameters.md`.
- **Attribute names never grow the atom table.** Names are resolved against a
  fixed lookup table, so a hostile document cannot exhaust the VM's atom table.

### When the parser gets stuck

The clause set is generated from the syntax map, so it is *closed*: every input
the parser can reach is covered by some declaration. If an input ever falls
through to the catch-all clause, that is a gap in the syntax definition (or a
bug in the engine), not merely an odd document.

Rather than a bare `FunctionClauseError`, `Md` logs the full context at `:error`
level and raises `Md.Parser.Error` carrying the same information:

```
Md: no `do_parse/2` clause matches this input.

  parser:       MyApp.Parser
  continuation: "<aside>hello"
  bytes left:   12
  mode:         [linefeed: 0]
  path:         [{:p, nil, []}]
  bag:          %{indent: [], stock: [], deferred: []}

  hint:         mode {:linefeed, 0} is open; the next bytes are "<aside>hello"
```

The `mode` is the most useful field: it names the construct whose clause is
missing. The exception exposes `continuation`, `mode`, `path`, `bag`, `parser`
and `hint` as struct fields, so a test or a crash reporter can assert on them
instead of parsing a message.

### Markup Handling

There are several different syntax patterns recognizable by `Md`. Those are:

- `custom` — the custom parser implementing `Md.Parser` behavious would be called
- `attributes` — inplace attributes for all tags `"{{foo:'bar'}}"` → `"<… foo='bar' …>"`
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
- `list` — a list, like `- one\n- two`
- `tag` — allowed tags (e. g. `<sup>2</sup>`)
- `brace` — a most common markdown feature, like text decoration or such (e. g. `**bold**`)

### Syntax description

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

A `block:` entry HTML-entity-escapes (`'`, `"`, `&`, `<`, `>`) its captured
content by default, same as `` ``` `` fenced code; set `escape: false` on a
specific entry to carry its content through verbatim instead (useful for a
custom block whose content isn't meant to become HTML).

For more examples of what properties are allowed for each kind of handlers,
see the sources (ATM.)

### Predefined parsers

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

### Changelog

- **`0.14.0`** fix deferred references and footnotes, which raised on every
  input; filter inline attributes (`:attribute_allowlist`, `on*` always
  refused, `javascript:` URIs rejected); stop attribute names from growing the
  atom table; `walker:` returning `nil` now drops the node instead of rendering
  `</>`; auto-linked URLs no longer swallow trailing punctuation; balanced
  parentheses inside `[text](url)` are preserved; unterminated pairs render as
  their literal source; DSL settings compose correctly; whitespace-only input
  produces no output
- **`0.12.2`** fix `Md.Parser.Syntax.merge/2` crashing when a custom `:settings`
  map is supplied; add an opt-out `escape: false` property for `block:` entries
  to carry content through verbatim instead of HTML-entity-escaping it
- **`0.10.4`** fix pairs with special symbols inside
- **`0.10.2`** spaces as delimiters in attributes
- **`0.10.1`** support for the flaky `floki` update
- **`0.10.0`** [:tag:] attributes for tags
- **`0.9.10`** [:ant:] escape in blocks (credits @adriansalamon,) sup, sub, center, youtube
- **`0.9.9`** [:ant:] fixed nested mixed lists
- **`0.9.7`** [:ant:] fixed custom parsers invocation
- **`0.9.4`** adds `class: "empty-anchor"` to tags expecting attributes to be set, fixed :ant: with nested brackets
- **`0.9.3`** adds `class: "empty-tag"` to empty tags to allow their display supression
- **`0.9.2`** nested tags shallow support, default support for `<dl>`
- **`0.9.1`** accept `config :md, :httpc_options` config used with `Floki` in TwitterCard/OG retrieval
- **`0.9.0`** use `unicode_set` instead of `string_naming` by default for guards
- **`0.8.5`** advanced `terminators:` in `magnet`
- **`0.8.4`** `Md.Parser.Syntax.merge/2`
- **`0.8.2`** `walker:` and `parser:` options in a call to `generate/2`
- **`0.8.0`** `Md.Transforms.Anchor` supporting twitter/og cards via `Floki`
- **`0.7.4`** configurable linebreaks (defaults: `\n`, `\r\n`)
- **`0.7.1`** `Md.Guards` through `StringNaming`
- **`0.7.0`** allow `payload` to be passed through within state
- **`0.6.8`** `xml_builder`→`xml_builder_ex` (default formatting for code is now `:none`)
- **`0.6.0`** allow HTML tags (without attributes yet)
- **`0.5.0`** DSL + `use Md.Parser, syntax: …`  for configurable syntax
- **`0.4.0`** configurable syntax as `@syntax`
- **`0.3.0`** relaxed support for comments and tables
- **`0.2.1`** deferred references like in `[link][1]` followed by `[1]: https://example.com` somewhere
- **`0.2.0`** PoC, most of reasonable markdown is supported

### Installation

```elixir
def deps do
  [
    {:md, "~> 0.1"}
  ]
end
```

### [Documentation](https://hexdocs.pm/md)
