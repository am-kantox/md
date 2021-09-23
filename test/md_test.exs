defmodule MdTest do
  use ExUnit.Case
  doctest Md

  test "leading spaces" do
    assert Md.parse("   foo") == {:p, [], "foo"}
  end
end
