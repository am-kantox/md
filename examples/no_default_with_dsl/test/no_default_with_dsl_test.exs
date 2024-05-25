defmodule NoDefaultWithDslTest do
  use ExUnit.Case
  doctest NoDefaultWithDsl

  @by %Md.Parser.State{type: NoDefaultWithDsl}

  test "explicit syntax" do
    assert [{:p, nil, ["I am ", {:del, nil, ["bold"]}, ", are you?"]}] ==
             Md.parse("I am *bold*, are you?", @by).ast
  end

  test "implicit syntax" do
    assert [{:p, nil, ["I am ", {:i, nil, ["italic"]}, ", are you?"]}] ==
             Md.parse("I am _italic_, are you?", @by).ast
  end

  test "DSL syntax" do
    assert [
             {:p, nil, ["I am a list"]},
             {:ol, nil, [{:li, nil, ["item"]}, {:li, nil, ["item"]}]},
             {:p, nil, ["Are you?"]}
           ] == Md.parse("I am a list\n\n+ item\n+ item\n\nAre you?", @by).ast
  end

  test "no default syntax" do
    assert [{:p, nil, ["I am ~not marked~, are you?"]}] ==
             Md.parse("I am ~not marked~, are you?", @by).ast
  end
end
