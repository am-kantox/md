defmodule NoDefaultWithDsl do
  @moduledoc false

  # explicit syntax definition to be passed to `use Md.Parser` explicitly
  @my_syntax %{settings: Md.Parser.Syntax.Void.settings(), brace: [{"*", %{tag: :del}}]}
  use Md.Parser, syntax: @my_syntax

  # implicitly loaded module attribute
  @syntax %{
    brace: [
      {"_", %{tag: :i}},
      {"`", %{tag: :code, mode: :raw, attributes: %{class: "code-inline"}}}
    ]
  }

  # syntax declared as DSL
  import Md.Parser.DSL

  list("- ", %{tag: :li, outer: :ul})
  list("+ ", %{tag: :li, outer: :ol})
end
