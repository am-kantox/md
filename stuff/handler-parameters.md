# Handler Parameters Reference

Every syntax definition in `md` is a map `%{handler_type => [{marker, properties}]}`.
Each handler type defines how a particular kind of markup is recognized and transformed
during the single-pass parse. Below is the complete reference for every handler type
and all the properties each one accepts.

## Settings

Settings are not a handler per se but configure global parser behavior. They live under
the `:settings` key in the syntax map.

- **`outer`** (`atom`) -- default outer container tag wrapping bare text. Default: `:p`.
- **`span`** (`atom`) -- default inline container tag. Default: `:span`.
- **`linebreaks`** (`[binary]`) -- list of binaries recognized as line breaks, tried in order.
  Default: `[<<?\r, ?\n>>, <<?\n>>]`.
- **`empty_tags`** (`[atom]`) -- tags that never need a closing counterpart (e.g. `img`, `hr`, `br`).
- **`requiring_attributes_tags`** (`[atom]`) -- tags that are hidden/wrapped when they have no attributes
  (e.g. `a` without `href`).
- **`linewrap`** (`boolean`) -- when `true`, every newline inside a paragraph inserts a `<br>` tag
  instead of a literal newline character. Default: `false`.
- **`disclosure_range`** (`Range.t()`) -- allowed length range for disclosure reference labels.
  Default: `3..5` (override in `Default` to `3..12`).

```elixir
%{
  settings: %{
    outer: :p,
    span: :span,
    linebreaks: [<<?\r, ?\n>>, <<?\n>>],
    empty_tags: ~w|img hr br|a,
    requiring_attributes_tags: ~w|a|a,
    linewrap: false,
    disclosure_range: 3..12
  }
}
```

---

## Syntax

## `escape`

Defines characters that, when immediately followed by another character, cause that
next character to be treated as literal text (no markup interpretation).

**Tuple format:** `{marker, properties}`

- **`marker`** (`binary`) -- the escape character.
- **`properties`** (`map`) -- currently unused; pass `%{}`.

```elixir
escape: [
  {<<92>>, %{}}   # backslash
]
```

**Effect:** `\*not bold\*` renders the literal asterisks.

---

## `comment`

Defines comment blocks. Everything between the opening and closing markers is captured
but not rendered. The content is delivered to the listener as `{:comment, stock}`.

**Properties:**

- **`closing`** (`binary`) -- closing marker. Default: same as opening marker.
- **`tag`** (`atom`) -- semantic tag name for listener events. Default: `:comment`.

```elixir
comment: [
  {"<!--", %{closing: "-->"}}
]
```

**Effect:** `<!-- hidden text -->` is stripped from output.

---

## `substitute`

Simple text replacement. When the marker is encountered (outside raw mode), it is
replaced with the given text in the output.

**Properties:**

- **`text`** (`binary`) -- replacement string. Default: `""`.

```elixir
substitute: [
  {"<", %{text: "&lt;"}},
  {"&", %{text: "&amp;"}}
]
```

**Effect:** a bare `<` in the source becomes `&lt;` in the output.

---

## `flush`

Markers that immediately produce an empty (self-closing) element and break the current
paragraph/block context.

**Properties:**

- **`tag`** (`atom | [atom]`) -- tag(s) to emit. **Required.**
- **`rewind`** (`false | true | :flip_flop`) -- how to handle preceding content.
  - `false` (default) -- just insert the tag.
  - `true` -- rewind (close) any open elements first.
  - `:flip_flop` -- close the current element and reopen a fresh one of the same kind
    (useful for `---` acting as a section separator).
- **`attributes`** (`map | nil`) -- HTML attributes for the emitted tag.

```elixir
flush: [
  {"---", %{tag: :hr, rewind: :flip_flop}},
  {"  \n", %{tag: :br}}
]
```

**Effect:** a line containing only `---` emits `<hr>` and starts a new section.

---

## `block`

Fenced blocks delimited by the same marker on opening and closing lines.
Content inside is parsed in the specified mode (`:raw` by default, meaning markup
is not interpreted). HTML entities inside raw blocks are auto-escaped.

**Properties:**

- **`tag`** (`atom | [atom]`) -- tag(s) to wrap the block. When a list is given,
  tags are nested (first = outermost). **Required.**
- **`mode`** -- parsing mode inside the block. Default: `:raw`.
  - `:raw` -- content is treated as literal text (HTML-escaped).
  - `{:outer, tag}` -- the block acts as an outer wrapper; content inside is
    parsed normally as top-level markup. The second element names the wrapper tag.
- **`pop`** (`map | nil`) -- attribute extraction from the first content token.
  Keys are tag atoms; values describe which attribute to populate from the leading text.
  - `%{tag: :attribute_name}` -- simple: first token becomes the attribute value.
  - `%{tag: [attribute: :attr, prefixes: ["", "lang-"]]}` -- the first token is
    joined with each prefix (space-separated) to form the attribute value.
- **`attributes`** (`map | nil`) -- static HTML attributes applied to the tag(s).

```elixir
block: [
  {"```", %{
    tag: [:pre, :code],
    pop: %{code: [attribute: :class, prefixes: ["", "lang-"]]}
  }}
]
```

**Effect:**

```elixir
IO.puts("hello")
```

produces `<pre><code class="elixir lang-elixir">IO.puts(&quot;hello&quot;)</code></pre>`.

**Outer block example** (wraps parsed content in a `<div>`):

```elixir
block: [
  {":::", %{tag: [:div], mode: {:outer, :div}}}
]
```

---

## `shift`

Indentation-based blocks. A line starting with the shift marker enters a block;
subsequent lines that also start with the marker continue the block. A line that
does _not_ start with the marker (or a blank line) closes it.

**Properties:**

- **`tag`** (`atom | [atom]`) -- tag(s) to wrap the block. **Required.**
- **`mode`** -- parsing mode inside the block. Default: `{:inner, :raw}`.
- **`attributes`** (`map | nil`) -- HTML attributes applied to the tag(s).
- **`pop`** (`map | nil`) -- attribute extraction, same semantics as in `block`.

```elixir
shift: [
  {"    ", %{tag: [:div, :code], attributes: %{class: "pre"}}}
]
```

**Effect:** four leading spaces produce a code block
(similar to standard markdown indented code blocks).

**Tab-based shift:**

```elixir
shift: [
  {"\t", %{
    tag: [:pre, :code],
    pop: %{code: [attribute: :class, prefixes: ["", "lang-"]]}
  }}
]
```

Multiple shift markers can coexist in the same syntax definition; each marker is
recognized independently.

---

## `pair`

Two-part constructs where the first segment provides display content and the second
provides metadata (href, src, title, etc.). This is the mechanism behind links,
images, and abbreviations.

**Properties:**

- **`tag`** (`atom | [atom]`) -- outer tag. **Required.**
- **`closing`** (`binary`) -- marker closing the first (content) segment. **Required.**
- **`inner_opening`** (`binary`) -- marker opening the second (metadata) segment. **Required.**
- **`inner_closing`** (`binary`) -- marker closing the second segment. **Required.**
- **`inner_tag`** (`atom | true`) -- tag for the inner element when `outer` is `{:tag, _}`.
  Default: `true` (boolean flag, not used as a tag name when `outer` is `{:attribute, _}`).
- **`outer`** -- determines how the two segments are combined:
  - `{:attribute, attr}` -- the second segment becomes attribute `attr` on the tag
    built from the first segment.
  - `{:attribute, {attr_content, attr_outer}}` -- two attributes: `attr_content` from
    the second segment, `attr_outer` from the first segment.
  - `{:tag, tag}` -- the second segment is rendered as a child element of type `tag`;
    the first segment is also a child.
  - `{:tag, {tag, attr}}` -- like `{:tag, tag}` but the second segment additionally
    populates attribute `attr` on the inner tag.
- **`disclosure_opening`** (`binary | nil`) -- if set, enables deferred/reference-style
  syntax where the second segment is a reference label enclosed in these markers.
- **`disclosure_closing`** (`binary | nil`) -- closing counterpart of `disclosure_opening`.
- **`attributes`** (`map | nil`) -- static HTML attributes.

```elixir
pair: [
  # Image: ![alt](src)
  {"![", %{
    tag: :img,
    closing: "]",
    inner_opening: "(",
    inner_closing: ")",
    outer: {:attribute, {:src, :title}}
  }},

  # Figure: !![caption](src)
  {"!![", %{
    tag: :figure,
    closing: "]",
    inner_opening: "(",
    inner_closing: ")",
    inner_tag: :img,
    outer: {:tag, {:figcaption, :src}}
  }},

  # Abbreviation: ?[abbr](title)
  {"?[", %{
    tag: :abbr,
    closing: "]",
    inner_opening: "(",
    inner_closing: ")",
    outer: {:attribute, :title}
  }},

  # Link with optional reference: [text](href) or [text][ref]
  {"[", %{
    tag: :a,
    closing: "]",
    inner_opening: "(",
    inner_closing: ")",
    disclosure_opening: "[",
    disclosure_closing: "]",
    outer: {:attribute, :href}
  }}
]
```

**Effect:** `[click me](https://example.com)` produces `<a href="https://example.com">click me</a>`.

---

## `disclosure`

Declares reference definitions that are resolved at the end of parsing.
Used together with `pair` entries that have `disclosure_opening`/`disclosure_closing`.

**Properties:**

- **`until`** -- what terminates the reference value.
  - `:eol` (default) -- end of line.
  - `binary` -- a specific closing string.

```elixir
disclosure: [
  {":", %{until: :eol}}
]
```

**Effect:** given `[text][ref]` in the document and `[ref]: https://example.com` as
a disclosure line, the link resolves at parse end.

---

## `paragraph`

Block-level elements that start at the beginning of a line (after optional leading
whitespace counted by the linefeed position). Supports nesting: repeated markers
increase the nesting depth.

**Properties:**

- **`tag`** (`atom | [atom]`) -- tag(s) for the element. When a list is given, tags nest
  (first = outermost). **Required.**
- **`mode`** -- parsing mode. Default: `{:nested, tag, 1}` (supports nesting).
- **`attributes`** (`map | nil`) -- HTML attributes.

```elixir
paragraph: [
  {"#", %{tag: :h1}},
  {"##", %{tag: :h2}},
  {"###", %{tag: :h3}},
  {"####", %{tag: :h4}},
  {"#####", %{tag: :h5}},
  {"######", %{tag: :h6}},
  # Nested blockquote:
  {">", %{tag: [:blockquote, :p]}}
]
```

**Effect:** `## Title` produces `<h2>Title</h2>`. Repeated `>` nests blockquotes:
`>> deep` produces `<blockquote><p><blockquote><p>deep</p></blockquote></p></blockquote>`.

---

## `list`

List item markers. Handles nesting via indentation tracking: deeper indentation
opens a nested list, shallower indentation closes back up.

**Properties:**

- **`tag`** (`atom | [atom]`) -- item tag(s). **Required.**
- **`outer`** (`atom`) -- container tag for the list. Default: `:ul`.
- **`attributes`** (`map | nil`) -- HTML attributes.

```elixir
list: [
  {"- ", %{tag: :li, outer: :ul}},
  {"* ", %{tag: :li, outer: :ul}},
  {"+ ", %{tag: :li, outer: :ul}},
  {"1. ", %{tag: :li, outer: :ol}},
  {"2. ", %{tag: :li, outer: :ol}}
  # ... up to the configured @ol_max
]
```

**Effect:**

```markdown
- first
  - nested
- second
```

produces `<ul><li>first</li><ul><li>nested</li></ul><li>second</li></ul>`.

---

## `brace`

Inline (span-level) markers that wrap content. The same marker opens and closes
(unless `closing` is set to something different). Can optionally switch the parser
into `:raw` mode to prevent further markup interpretation inside.

**Properties:**

- **`tag`** (`atom | [atom]`) -- tag(s) to wrap content. **Required.**
- **`mode`** (`atom | nil`) -- parsing mode inside the brace.
  - `nil` (default) -- normal markdown parsing continues inside.
  - `:raw` -- content is treated as literal text (no nested markup).
- **`closing`** (`binary`) -- closing marker. Default: same as the opening marker.
- **`attributes`** (`map | nil`) -- HTML attributes.

```elixir
brace: [
  {"*", %{tag: :b}},
  {"_", %{tag: :i}},
  {"**", %{tag: :strong, attributes: %{class: "red"}}},
  {"__", %{tag: :em}},
  {"~", %{tag: :s}},
  {"~~", %{tag: :del}},
  {"`", %{tag: :code, mode: :raw, attributes: %{class: "code-inline"}}},
  {"``", %{tag: :span, mode: :raw, attributes: %{class: "code-inline"}}},
  {"[^", %{closing: "]", tag: :b, mode: :raw}}
]
```

**Effect:** `*bold*` produces `<b>bold</b>`;
`` `code` `` produces `<code class="code-inline">code</code>` with no markup inside.

---

## `tag`

Pass-through for literal HTML tags written as `<tag>...</tag>` in the source.
The parser recognizes the opening and closing forms and captures content between them.

**Properties:**

- **`tag`** (`atom`) -- the Elixir atom for the tag. Default: `String.to_atom(md)`.
- **`mode`** (`atom`) -- parsing mode inside. Default: `:md` (normal parsing).
- **`closing`** (`binary`) -- closing tag string. Default: `"</#{tag}>"`.
- **`attributes`** (`map | nil`) -- HTML attributes.

```elixir
tag: [
  {"sup", %{}},
  {"sub", %{}},
  {"kbd", %{}},
  {"dl", %{}},
  {"dt", %{}},
  {"dd", %{}}
]
```

**Effect:** `<kbd>Ctrl</kbd>` passes through as `<kbd>Ctrl</kbd>`.

---

## `matrix`

Table/grid structures. A single marker separates cells; linebreaks separate rows.
The first row uses `first_inner_tag` (typically `:th`), subsequent rows use `tag`.

**Properties:**

- **`tag`** (`atom`) -- cell tag for body rows. Default: `:div`.
- **`outer`** (`atom`) -- outermost container tag. Default: `:div`.
- **`inner`** (`atom`) -- row container tag. Default: same as `outer`.
- **`first_inner_tag`** (`atom`) -- cell tag for the header (first) row. Default: same as `tag`.
- **`skip`** (`binary | nil`) -- when a line starts with this marker, the entire line is skipped
  (used for separator rows like `|---|---|`).
- **`extras`** (`%{binary => atom}`) -- additional markers recognized inside the matrix that
  switch to a different tag (e.g. `"#"` for `<caption>`).
- **`attributes`** (`map | nil`) -- HTML attributes on the outer tag.

```elixir
matrix: [
  {"|", %{
    tag: :td,
    outer: :table,
    inner: :tr,
    first_inner_tag: :th,
    skip: "|-",
    extras: %{"#" => :caption}
  }}
]
```

**Effect:**

```markdown
| Name | Age
|- 
| Alice | 30
| Bob | 25
# People
```

produces a `<table>` with `<th>` header cells, `<td>` body cells,
separator rows skipped, and `<caption>` from `#`.

---

## `magnet`

Single-token markers that "magnetize" the immediately following word.
When the marker is encountered, the parser collects characters until it hits
a terminator (whitespace or specified punctuation), then passes the collected
text through a transform function.

**Properties:**

- **`transform`** (`(binary, binary -> Md.Listener.branch()) | module`) -- transformation
  applied to the collected text. Either a function of arity 2 `(marker, text)`, or a module
  implementing `Md.Transforms` (which defines `apply/2`). **Required.**
- **`terminators`** -- what ends the magnet word. Default: `:ascii_punctuation`.
  - `:ascii_punctuation` -- any ASCII punctuation character.
  - `:utf8_punctuation` -- any Unicode punctuation character.
  - list of codepoints (integers) -- specific characters, e.g. `[?,, ?., ?!]`.
  - `[]` -- only whitespace terminates (greedy collection).
- **`greedy`** -- controls whether the marker prefix and/or the delimiter suffix
  are included in the output passed to the transform:
  - `false` (default) -- neither marker nor delimiter included.
  - `true` / `:both` -- both marker and delimiter included.
  - `:left` -- marker prefix included, delimiter not.
  - `:right` -- delimiter included, marker not.
- **`ignore_in`** (`[atom]`) -- list of parent tag names inside which this magnet
  should not trigger. Default: `[]`.

```elixir
magnet: [
  # Footnotes
  {"[^", %{
    transform: Md.Transforms.Footnote,
    terminators: [?\]],
    greedy: true,
    ignore_in: [:img, :a, :figure, :abbr]
  }},

  # Twitter handles: @username
  {"@", %{
    transform: &Md.Transforms.TwitterHandle.apply/2,
    terminators: [?,, ?., ?!, ??, ?:, ?;, ?[, ?], ?(, ?)],
    ignore_in: [:img, :a, :figure, :abbr]
  }},

  # Auto-linked URLs
  {"https://", %{
    transform: Md.Transforms.Anchor,
    terminators: [],
    greedy: :left,
    ignore_in: [:img, :a, :figure, :abbr]
  }}
]
```

**Effect:** `@john` produces `<a href="https://twitter.com/john">@john</a>`.

The `Md.Transforms` behaviour requires a single callback:

```elixir
@callback apply(marker :: binary(), collected_text :: binary()) :: Md.Listener.branch()
```

---

## `custom`

Delegate parsing to an external module or function when a specific marker is encountered.
The handler receives the remaining input and current state, and must return
`{continuation_input, updated_state}`.

**Tuple format:** `{marker, {handler, properties}}`

Note the different tuple shape: the second element is itself a `{handler, properties}` tuple.

- **`handler`** (`module | (binary, state -> {binary, state})`) -- either a module
  implementing `parse/2` or a function of arity 2.
- **`properties.rewind`** (`boolean`) -- whether to rewind (close open elements) before
  invoking the handler. Default: `false`.

```elixir
custom: [
  {"!!!", {MyApp.AlertParser, %{rewind: true}}}
]
```

The handler module must implement:

```elixir
@spec parse(binary(), Md.Parser.State.t()) :: {binary(), Md.Parser.State.t()}
```

---

## `attributes`

Inline attribute injection. When the opening marker appears immediately after an element,
the parser switches to raw mode and collects key-value pairs until the closing marker.
The attributes are then merged onto the preceding element.

Attribute syntax inside the markers supports:

- `key:value` or `key=value` pairs
- Bare `key` (treated as `key: true`)
- Multiple pairs separated by spaces, commas, or pipes

**Properties:**

- **`closing`** (`binary`) -- closing marker. Default: same as opening.

```elixir
attributes: [
  {"{{", %{closing: "}}"}}
]
```

**Effect:** `*bold*{{class:"highlight", id:main}}` applies `class="highlight"` and `id="main"`
to the `<b>` tag.

---

## Processing Order

Handlers are tried in the order they are expanded within the engine. This order matters
when markers could be ambiguous. The expansion order is:

1. `block`
2. `flush`
3. `shift`
4. `tag`
5. `escape`
6. `comment`
7. `matrix`
8. `disclosure`
9. `magnet`
10. `custom`
11. `substitute`
12. `pair`
13. `paragraph`
14. `list`
15. `brace`
16. `attributes`

Within each handler type, syntax items are sorted by **descending marker length**
during syntax merge, so longer markers are tried before shorter ones
(e.g. `"**"` before `"*"`, `"##"` before `"#"`).
