defmodule Md.DSL.Test do
  use ExUnit.Case
  doctest Md.Parser.DSL

  test "correctly handles DSL" do
    assert MyDSLParser.syntax()[:comment] == [{"<!--", %{closing: "-->"}}]
    assert MyDSLParser.syntax()[:brace] == [{"***", %{tag: "u"}}]
  end

  test "DSL is used properly" do
    assert [
             {:p, nil,
              [
                "L1",
                {:br, [], []},
                {"u", nil, ["L2"]},
                " ",
                {:a,
                 %{
                   href: "/tags/L3",
                   class: "tag",
                   "data-tag": "l3"
                 }, ["%L3"]},
                {:br, [], []}
              ]}
           ] ==
             elem(MyDSLParser.parse("L1\n***L2*** %L3"), 1).ast
  end
end
