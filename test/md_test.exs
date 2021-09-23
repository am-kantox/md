defmodule MdTest do
  use ExUnit.Case
  doctest Md

  test "leading spaces" do
    assert Md.parse(" he\\*llo \n  *foo **bar baz \n   \n Answer: _42_.") == %Md.Parser.State{
             ast: [
               {:p, [], ["Answer: ", {:it, %{}, ["42"]}, "."]},
               {:p, [], ["he*llo  ", {:b, %{}, ["foo ", {:strong, %{}, ["bar baz  "]}]}]}
             ],
             path: []
           }
  end
end
