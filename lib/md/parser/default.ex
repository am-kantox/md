defmodule Md.Parser.Default do
  @moduledoc """
  Default parser with all the features included.

  Supports a wide subset of markdown, including but not limited to:

  - bold/italic/strikeout/etc text decorations
  - comments
  - code blocks and indented code
  - tables (with captions)
  - links, images, figures, abbreviations
  - deferred references (`[text][1]` with `[1]: url` elsewhere) and footnotes
    (`text[^1]`, rendered as `<a href="#1"><sup>1</sup></a>`)
  - auto-linked URLs and `@handles`
  - blockquotes, ordered and unordered lists (nested)
  - inline attributes (`{{class: "x"}}`), filtered by `:attribute_allowlist`

  This is deliberately *not* a CommonMark implementation: lists keep the
  simplified nesting model described in the README, and there is no setext
  heading support. It is a good start for anyone who needs fast markdown
  processing with room to extend the syntax.
  """

  use Md.Parser

  alias Md.Parser.Syntax

  @syntax Syntax.merge(Application.compile_env(:md, :syntax, %{}))
end
