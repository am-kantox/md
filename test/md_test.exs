defmodule MdTest do
  use ExUnit.Case
  doctest Md

  test "leading spaces" do
    assert %Md.Parser.State{
             mode: [:finished],
             ast: [
               {:p, nil,
                [
                  "he*llo ",
                  "\n",
                  {:b, nil, ["foo ", {:strong, %{class: "red"}, ["bar baz "]}]}
                ]},
               {:p, nil, ["Answer: ", {:it, nil, ["42"]}, "."]}
             ]
           } = Md.parse("   he\\*llo \n  *foo **bar baz \n\n Answer: _42_.")
  end

  test "substitutes" do
    assert [{:p, nil, ["foo &lt;br> bar"]}] == Md.parse("foo <br> bar").ast
  end

  test "flush" do
    assert [{:p, nil, ["foo "]}, {:hr, nil, []}, {:p, nil, ["bar"]}] ==
             Md.parse("foo --- bar").ast

    assert [{:p, nil, ["foo", {:br, nil, []}, "bar"]}] == Md.parse("foo  \nbar").ast
  end

  test "block" do
    input = """
    foo

    ```elixir
    def foo, do: :ok

    def bar, do: :error
    ```
    """

    assert [
             {:p, nil, ["foo"]},
             {:pre, nil,
              [
                {:code, %{class: "elixir"},
                 ["def foo, do: :ok", "\n", "\n", "def bar, do: :error"]}
              ]}
           ] ==
             Md.parse(input).ast
  end

  test "nested" do
    input = """
    - 1 | 1
      - 2 | 1
      - 2 | 2
    - 1 | 2
      - 2 | 3
    - 1 | 3
    """

    assert [
             {:ul, nil,
              [
                {:li, nil, ["1 | 1"]},
                {:ul, nil,
                 [
                   {:li, nil, ["2 | 1"]},
                   {:li, nil, ["2 | 2"]}
                 ]},
                {:li, nil, ["1 | 2"]},
                {:ul, nil, [{:li, nil, ["2 | 3"]}]},
                {:li, nil, ["1 | 3"]}
              ]}
           ] = Md.parse(input).ast
  end

  test "deeply nested" do
    input = """
    - 1 | 1
      - 2 | 1
        - 3 | 1
          - 4 | 1
      - 2 | 2
    - 1 | 2
    """

    assert [
             {:ul, nil,
              [
                {:li, nil, ["1 | 1"]},
                {:ul, nil,
                 [
                   {:li, nil, ["2 | 1"]},
                   {:ul, nil, [{:li, nil, ["3 | 1"]}, {:ul, nil, [{:li, nil, ["4 | 1"]}]}]},
                   {:li, nil, ["2 | 2"]}
                 ]},
                {:li, nil, ["1 | 2"]}
              ]}
           ] = Md.parse(input).ast
  end

  test "simple markdown" do
    assert "priv/SIMPLE.md" |> File.read!() |> Md.parse() == %Md.Parser.State{
             mode: [:finished],
             ast: [
               {:h1, nil, ["Header 1"]},
               {:h2, nil, ["Header 2"]},
               {:p, nil,
                [
                  "he*llo  ",
                  {:b, nil, ["foo ", {:strong, %{class: "red"}, ["bar"]}, "\n", "baz"]},
                  " 42"
                ]},
               {:blockquote, nil, ["Hi, ", {:b, nil, ["there"]}, "olala"]},
               {:blockquote, nil,
                [
                  "Hi, ",
                  {:figure, nil,
                   [{:figcaption, nil, ["image"]}, {:img, %{src: "https://image.com"}, []}]},
                  "\n",
                  {:blockquote, nil,
                   [
                     "2nd ",
                     {:b, nil, ["1st"]},
                     " line",
                     "\n",
                     "2nd ",
                     {:code, %{class: "code-inline"}, ["2nd"]},
                     " line"
                   ]},
                  "boom"
                ]},
               {:ul, nil,
                [
                  {:li, nil, ["1 | ", {:b, nil, ["foo"]}, " foo"]},
                  {:li, nil, ["1 | bar ", {:it, nil, ["bar"]}]},
                  {:ul, nil,
                   [
                     {:li, nil, ["2 | baz"]},
                     {:li, nil, ["2 | bzz"]},
                     {:ul, nil, [{:li, nil, ["3 | rgf"]}]}
                   ]},
                  {:li, nil, ["1 | zzz"]}
                ]},
               {:p, nil, ["Hi ", {:a, %{href: "https://anchor.com"}, ["anchor"]}, " 1!"]},
               {:pre, nil,
                [
                  {:code, %{class: "elixir"},
                   ["def foo, do: :ok", "\n", "\n", "def bar, do: :error"]}
                ]},
               {:ul, nil,
                [
                  {:li, nil,
                   [
                     "Hi ",
                     {:a, %{href: "https://anchor.com"}, ["anchor"]},
                     " ",
                     {:b, nil, ["bar"]}
                   ]},
                  {:li, nil, ["baz"]}
                ]}
             ],
             listener: Md.Listener.Debug
           }
  end
end
