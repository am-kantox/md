# Custom Markdown Pipelines

Looking for a flexible, extensible, and blazingly fast markup processor that goes beyond standard markdown? Meet `md`, a highly customizable markup processing library that lets you define your own markup syntax and transformation rules.

## Not Just Another Markdown Parser

Unlike traditional markdown parsers that offer a fixed set of features, `md` is designed as a toolkit for building custom markup processing pipelines. Think of it as LEGO® for text processing - you get the basic building blocks and the freedom to assemble them however you want.

## Key Features

### 🔧 Fully Customizable Syntax

- Define your own markup patterns
- Support for custom tags and attributes
- Extensible parser behavior
- Build your own DSL for specific needs

### 🚀 Stream-Aware Processing

- Process content in a single pass
- Maintains state throughout parsing
- Efficient memory usage for large documents
- Error recovery capabilities

### 🧩 Transform Pipeline

Built-in transforms that you can mix and match:
- Twitter Cards and OpenGraph data extraction
- YouTube video embedding
- SoundCloud track embedding
- Twitter handle linking
- Footnote processing
- And more!

### ⚡ Performance First

- Single-pass parsing
- Stream-based processing
- Minimal memory footprint
- No unnecessary reparsing

## Use Cases

Perfect for:
- Custom documentation systems
- Domain-specific markup languages
- Content management systems
- Social media content processing
- Technical documentation with custom needs

## Example: Custom Syntax

```elixir
defmodule MyParser do
  use Md.Parser

  # Define your own syntax patterns
  @syntax %{
    comment: [{"<!--", %{closing: "-->"}}],
    paragraph: [
      {"##", %{tag: :h2}},
      {"###", %{tag: :h3}},
      {">", %{tag: :blockquote}}
    ],
    list: [
      {"- ", %{tag: :li, outer: :ul}},
      {"+ ", %{tag: :li, outer: :ol}}
    ],
    brace: [
      {"*", %{tag: :b}},
      {"_", %{tag: :i}},
      {"~", %{tag: :s}},
      {"`", %{tag: :code, mode: :raw}}
    ]
  }
end
```

## Using the DSL Syntax

In addition to defining syntax using maps, `md` provides a declarative DSL for defining your markup rules:

```elixir
defmodule MyDSLParser do
  use Md.Parser, dsl: true
  
  # Basic markup elements
  brace "*", %{tag: :strong}
  brace "_", %{tag: :em}
  brace "`", %{tag: :code, mode: :raw}
  
  # Headers and paragraphs
  paragraph "#", %{tag: :h1}
  paragraph "##", %{tag: :h2}
  paragraph ">", %{tag: :blockquote}
  
  # Lists
  list "- ", %{tag: :li, outer: :ul}
  list "* ", %{tag: :li, outer: :ul}
  list "1. ", %{tag: :li, outer: :ol}
  
  # Custom elements
  magnet "#", %{tag: :span, class: "hashtag"}
  magnet "@", %{tag: :a, href: "https://twitter.com/{{text}}"}
  
  # Special blocks
  block "```", %{tag: :pre, class: "code"}
  block "~~~", %{tag: :div, class: "quote"}
  
  # Comments
  comment "<!--", %{closing: "-->"}
  
  # Parser settings
  outer :article
  span :span
  empty_tags ~w|br hr img|a
  linebreaks ~w|\n \r\n|
end
```

The DSL supports all markdown element types:
- `:custom` - Custom parsers for special syntax
- `:attributes` - Inline attribute definitions
- `:substitute` - Simple text substitutions
- `:escape` - Characters to be escaped
- `:comment` - Comment syntax
- `:matrix` - Table and matrix syntax
- `:flush` - Paragraph break markers
- `:magnet` - Single-word markers like #tags
- `:block` - Multi-line blocks
- `:shift` - Indentation-based blocks
- `:pair` - Opening/closing pairs
- `:disclosure` - Reference declarations
- `:paragraph` - Block-level elements
- `:list` - List item markers
- `:tag` - HTML tag handling
- `:brace` - Inline markup

Parser settings can be configured with:
- `outer` - Default outer container tag
- `span` - Default inline container tag
- `linebreaks` - Line break characters
- `disclosure_range` - Range for reference numbering
- `empty_tags` - Tags that don’t need closing
- `requiring_attributes_tags` - Tags that must have attributes
- `linewrap` - Enable/disable line wrapping

## Transform Pipeline Example

```elixir
# Basic parsing with default settings
content
|> Md.generate(Md.Parser.Default)

# With custom parser and formatting options
content
|> Md.generate(MyParser, format: :none)
```

## When to Use Md

Choose `md` when you need:
- Custom markup syntax beyond standard markdown
- Flexible processing pipeline
- High-performance text processing
- Stream-based content handling
- Error recovery capabilities

Don’t choose `md` when you:
- Need a drop-in markdown parser
- Want 100% CommonMark compatibility
- Don’t require custom syntax or transforms

## Getting Started

Add to your mix.exs:

```elixir
def deps do
  [{:md, "~> 0.10"}]
end
```

## Learn More

Check out the [documentation](https://hexdocs.pm/md) for detailed examples and API reference.

---

`md` isn’t trying to be another markdown parser—it’s a toolkit for building your own markup processing pipeline. If you need flexibility, performance, and custom syntax support, give it a try!

