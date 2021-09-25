defmodule MdTest do
  use ExUnit.Case
  doctest Md

  test "leading spaces" do
    assert Md.parse(" he\\*llo \n  *foo **bar baz \n   \n Answer: _42_.") == %Md.Parser.State{
             ast: [
               {:p, [],
                ["he*llo  ", {:b, nil, ["foo ", {:strong, %{class: "red"}, ["bar baz  "]}]}]},
               {:p, [], ["Answer: ", {:it, nil, ["42"]}, "."]}
             ],
             listener: Md.Parser.DebugListener
           }
  end
end
