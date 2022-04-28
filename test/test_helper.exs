defmodule MyDSLParser do
  @my_syntax %{brace: [{"***", %{tag: "u"}}]}

  use Md.Parser, syntax: @my_syntax
  import Md.Parser.DSL

  comment "<!--", %{closing: "-->"}
end

ExUnit.start()
