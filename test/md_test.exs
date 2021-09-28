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
             listener: Md.Listener.Debug
           }
  end

  test "simple markdown" do
    assert "priv/SIMPLE.md" |> File.read!() |> Md.parse() == %Md.Parser.State{
             ast: [
               {:h1, nil, ["Header 1 "]},
               {:h2, nil, ["Header 2 "]},
               {:p, nil,
                [
                  "he*llo  ",
                  {:b, nil, ["foo ", {:strong, %{class: "red"}, ["bar"]}, " baz"]},
                  " 42 "
                ]},
               {:blockquote, nil, ["Hi, ", {:b, nil, ["there "]}, "olala "]},
               {:blockquote, nil,
                ["Hi, there ", {:blockquote, nil, ["2nd 1st line 2nd 2nd line "]}, "boom "]},
               {
                 :ul,
                 nil,
                 [
                   {:li, nil, [" 1 | foo "]},
                   {:li, nil, [" 1 | bar "]},
                   {:li, nil,
                    [
                      {:ul, nil,
                       [
                         {:li, nil, [" 2 | baz "]},
                         {:li, nil, [" 2 | bzz "]},
                         {:li, nil, [{:ul, nil, [{:li, nil, [" 3 | rgf "]}]}]}
                       ]}
                    ]},
                   {:li, nil, [" 1 | zzz "]}
                 ]
               },
               {:p, nil, ["Hi "]},
               {:ul, nil, [{:li, nil, [" 1 | item 1  "]}, {:li, nil, [" 1 | item 2 "]}]}
             ],
             listener: Md.Listener.Debug
           }
  end
end
