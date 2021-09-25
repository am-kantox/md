defmodule MdTest do
  use ExUnit.Case
  doctest Md

  test "leading spaces" do
    assert Md.parse(" he\\*llo \n  *foo **bar baz \n   \n Answer: _42_.") == %Md.Parser.State{
             ast: [
               {:p, nil,
                ["he*llo  ", {:b, nil, ["foo ", {:strong, %{class: "red"}, ["bar baz  "]}]}]},
               {:p, nil, ["Answer: ", {:it, nil, ["42"]}, "."]}
             ],
             listener: Md.Parser.DebugListener
           }
  end

  test "simple markdown" do
    assert "priv/SIMPLE.md" |> File.read!() |> Md.parse() == %Md.Parser.State{
             ast: [
               {:h1, nil, [" Header 1 "]},
               {:h2, nil, [" Header 2 "]},
               {:p, nil,
                [
                  "he*llo  ",
                  {:b, nil, ["foo ", {:strong, %{class: "red"}, ["bar"]}, " baz"]},
                  " 42 "
                ]},
               {:blockquote, nil, [" Hi, there  olala "]},
               {:blockquote, nil, [" Hi, there ", {:blockquote, %{nested: 1}, [" olala "]}]}
             ],
             listener: Md.Parser.DebugListener
           }
  end
end
