defmodule Md.DSL.Test do
  use ExUnit.Case
  doctest Md.Parser.DSL

  test "correctly handles DSL" do
    assert MyDSLParser.syntax()[:comment] == [{"<!--", %{closing: "-->"}}]
    assert MyDSLParser.syntax()[:brace] == [{"***", %{tag: "u"}}]
  end
end
