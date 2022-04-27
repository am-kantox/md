defmodule MdUtilsTest do
  use ExUnit.Case
  doctest Md.Engine

  test "closing_match/1" do
    assert [
             {:{}, [], [:c, {:_, [], nil}, {:_, [], nil}]},
             {:{}, [], [:b, {:_, [], nil}, {:_, [], nil}]},
             {:{}, [], [:a, {:_, [], nil}, {:_, [], nil}]}
           ] = Md.Engine.closing_match([:a, :b, :c])
  end
end
