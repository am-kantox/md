defmodule MdUtilsTest do
  use ExUnit.Case
  doctest Md.Utils

  test "closing_match/1" do
    assert [
             {:{}, [], [:c, {:_, [], nil}, {:_, [], nil}]},
             {:{}, [], [:b, {:_, [], nil}, {:_, [], nil}]},
             {:{}, [], [:a, {:_, [], nil}, {:_, [], nil}]}
           ] = Md.Utils.closing_match([:a, :b, :c])
  end
end
