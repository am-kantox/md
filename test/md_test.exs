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
                  {:b, nil, ["foo ", {:strong, %{class: "red"}, ["bar"]}, "  baz"]},
                  " 42 "
                ]},
               {:blockquote, nil, ["Hi, ", {:b, nil, ["there "]}, "olala "]},
               {:blockquote, nil,
                [
                  "Hi, ",
                  {:figure, nil,
                   [{:figcaption, nil, ["image"]}, {:img, %{src: "https://image.com"}, []}]},
                  " ",
                  {:blockquote, nil,
                   [
                     "2nd ",
                     {:b, nil, ["1st"]},
                     " line 2nd ",
                     {:code, %{class: "code-inline"}, ["2nd"]},
                     " line "
                   ]},
                  "boom "
                ]},
               {
                 :ul,
                 nil,
                 [
                   {:li, nil, ["1 | ", {:b, nil, ["foo"]}, " foo "]},
                   {:li, nil, ["1 | bar ", {:it, nil, ["bar"]}, " "]},
                   {:li, nil,
                    [
                      {:ul, nil,
                       [
                         {:li, nil, ["2 | baz "]},
                         {:li, nil, ["2 | bzz "]},
                         {:li, nil, [{:ul, nil, [{:li, nil, ["3 | rgf "]}]}]}
                       ]}
                    ]},
                   {:li, nil, ["1 | zzz "]}
                 ]
               },
               {:p, nil, ["Hi ", {:a, %{href: "https://anchor.com"}, ["anchor"]}, " 1! "]},
               {:ul, nil,
                [
                  {:li, nil,
                   [
                     "Hi ",
                     {:a, %{href: "https://anchor.com"}, ["anchor"]},
                     " ",
                     {:b, nil, ["bar"]},
                     " "
                   ]},
                  {:li, nil, ["baz "]}
                ]}
             ],
             listener: Md.Listener.Debug
           }
  end
end
