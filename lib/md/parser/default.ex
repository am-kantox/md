defmodule Md.Parser.Default do
  @moduledoc """
  Default parser with all the features included.

  Supports a wide subset of markdown, including but not limited to:

  - bold/italic/strikeout/etc text decorations
  - comments
  - code blocks
  - tables
  - twitter handlers etc

  Might be a good start for those who just needs a fast markdown processing.
  """

  use Md.Parser

  alias Md.Parser.Syntax

  @syntax Syntax.merge(Application.compile_env(:md, :syntax, %{}))
end
