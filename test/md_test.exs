defmodule MdTest do
  use ExUnit.Case
  doctest Md

  test "leading spaces" do
    assert Md.parse("   foo") == %Md.Parser.State{ast: [{:p, [], ["foo"]}], path: []}
  end
end
