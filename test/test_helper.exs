defmodule MyDSLParser do
  use Md.Parser, dsl: true
  import Md.Parser.DSL

  comment "<!--", %{closing: "-->"}
end

ExUnit.start()
