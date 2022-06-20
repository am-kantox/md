defmodule MdTest do
  use ExUnit.Case
  doctest Md
  doctest Md.Guards

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
               {:p, nil, ["Answer: ", {:i, nil, ["42"]}, "."]}
             ]
           } = Md.parse("   he\\*llo \n  *foo **bar baz \n\n Answer: _42_.")
  end

  test "linefeeds" do
    assert [{:p, nil, ["L1"]}, {:p, nil, ["L2"]}] == Md.parse("L1\n\nL2").ast
    assert [{:p, nil, ["L1"]}, {:p, nil, ["L2"]}] == Md.parse("L1\r\n\r\nL2").ast
  end

  test "substitutes" do
    assert [{:p, nil, ["foo &lt;br> bar"]}] == Md.parse("foo <br> bar").ast
  end

  test "comment" do
    input = """
    This is a text.
    <!-- This is the comment. -->

    <!--
    This is the multiline comment.
    -->

    This is another text.
    """

    assert [{:p, nil, ["This is a text."]}, {:p, nil, ["This is another text."]}] =
             Md.parse(input).ast
  end

  test "magnet" do
    input = """
    This is a text with a reference to ⚓https://example.com and like.

    This is @mudasobwa twitter reference.
    """

    assert [
             {:p, nil,
              [
                "This is a text with a reference to ",
                {:a, %{href: "https://example.com"}, ["https://example.com"]},
                " and like."
              ]},
             {:p, nil,
              [
                "This is ",
                {:a, %{href: "https://twitter.com/mudasobwa"}, ["@mudasobwa"]},
                " twitter reference."
              ]}
           ] == Md.parse(input).ast

    assert [
             {:p, nil, [{:a, %{href: "https://twitter.com/derek"}, ["@derek"]}]}
           ] == Md.parse("@derek").ast

    assert [
             {:p, nil,
              ["Hi, ", {:a, %{href: "https://twitter.com/derek"}, ["@derek"]}, ", are you ok?"]}
           ] == Md.parse("Hi, @derek, are you ok?").ast

    assert [{:p, nil, [{:a, %{href: "https://twitter.com/derek"}, ["@derek"]}, ", are you ok?"]}] ==
             Md.parse("@derek, are you ok?").ast

    assert [{:p, nil, [{:a, %{href: "https://twitter.com/王"}, ["@王"]}]}, {:p, nil, ["foo"]}] ==
             Md.parse("@王\nfoo").ast

    assert [
             {:p, nil, [{:a, %{href: "https://twitter.com/@"}, ["@@"]}]}
           ] == Md.parse("@@").ast

    assert [
             {:p, nil, [{:a, %{href: "https://twitter.com/@bar"}, ["@@bar"]}]}
           ] == Md.parse("@@bar").ast

    assert [
             {:p, nil, [{:a, %{href: "https://twitter.com/@@bar"}, ["@@@bar"]}]}
           ] == Md.parse("@@@bar").ast
  end

  test "flush" do
    assert [{:p, nil, ["foo "]}, {:hr, nil, []}, {:p, nil, ["bar"]}] ==
             Md.parse("foo --- bar").ast

    assert [{:p, nil, ["foo", {:br, nil, []}, "bar"]}] == Md.parse("foo  \nbar").ast
  end

  test "brace" do
    assert %Md.Parser.State{
             mode: [:finished],
             ast: [
               {:p, nil, ["he", {:b, nil, ["llo"]}, " ", {:i, nil, ["kit"]}, "ty"]}
             ]
           } = Md.parse("   he*llo* _kit_ty")
  end

  test "tag" do
    assert %Md.Parser.State{
             mode: [:finished],
             ast: [
               {:p, nil, ["hello", {:sup, nil, ["2"]}]}
             ]
           } = Md.parse("   hello<sup>2</sup>")
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
                {:code, %{class: "elixir"}, ["def foo, do: :ok\n\ndef bar, do: :error\n"]}
              ]}
           ] ==
             Md.parse(input).ast

    input = """
    ```
    a
    b
    c
    ```
    """

    assert [{:pre, nil, [{:code, nil, ["a\nb\nc\n"]}]}] ==
             Md.parse(input).ast

    assert "<pre>\n  <code>\n    a\nb\nc\n\n  </code>\n</pre>" ==
             Md.generate(input, Md.Parser.Default, format: :indent)

    assert "<pre><code>a\nb\nc\n</code></pre>" ==
             Md.generate(input)

    input = """
    ```
    `inline-code`
    ```
    """

    assert [{:pre, nil, [{:code, nil, ["`inline-code`\n"]}]}] == Md.parse(input).ast
  end

  test "codeblock" do
    input = """
    foo

        defmodule Foo
            def bar, do: :baz
        end

    bar
    """

    assert [
             {:p, nil, ["foo"]},
             {:div, %{class: "pre"},
              [
                {:code, %{class: "pre"}, ["defmodule Foo", "\n    def bar, do: :baz", "\nend"]}
              ]},
             {:p, nil, ["bar"]}
           ] == Md.parse(input).ast
  end

  test "nested list" do
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
           ] == Md.parse(input).ast
  end

  test "deeply nested list" do
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
           ] == Md.parse(input).ast
  end

  test "list from #12" do
    input = ["- a - ", "- 1. ", "1. - "]

    expectation = [
      [{:ul, nil, [{:li, nil, ["a - "]}]}],
      [{:ul, nil, [{:li, nil, ["1. "]}]}],
      [{:ol, nil, [{:li, nil, ["- "]}]}]
    ]

    input
    |> Enum.zip(expectation)
    |> Enum.each(fn {input, expectation} ->
      assert expectation == Md.parse(input).ast
    end)
  end

  test "blockquote" do
    input = """
    This is a paragraph.
    > Blockquote.
    """

    assert [{:p, nil, ["This is a paragraph."]}, {:blockquote, nil, [{:p, nil, ["Blockquote."]}]}] ==
             Md.parse(input).ast

    Enum.each(0..10, fn i ->
      assert [
               {:blockquote, nil,
                [{:p, nil, ["top line (#{i})"]}, {:p, nil, ["\nbottom line (#{i})"]}]}
             ] ==
               Md.parse(
                 ">top line (#{i})\n>#{" " |> List.duplicate(i) |> Enum.join()}\n>bottom line (#{i})"
               ).ast
    end)

    assert [{:blockquote, nil, [{:p, nil, ["&lt;me@example.com>"]}]}] ==
             Md.parse("> <me\\@example.com>").ast

    assert [{:blockquote, nil, [{:p, nil, ["line 1"]}, {:p, nil, ["\nline2"]}]}] ==
             Md.parse("\n> line 1\n> \n> line2").ast

    assert [
             {:blockquote, nil, [{:p, nil, ["line 1", "\n", {:i, nil, []}, "line 2"]}]}
           ] ==
             Md.parse(">line 1\n>_\n>line 2").ast

    assert [
             {:blockquote, nil,
              [{:p, nil, ["line 1", "\n", {:em, nil, [{:i, nil, []}]}, "line 2"]}]}
           ] ==
             Md.parse(">line 1\n>___\n>line 2").ast

    assert [
             {:blockquote, nil,
              [
                {:p, nil, ["line 1", "\n", {:em, nil, []}, {:em, nil, [{:i, nil, []}]}, "line 2"]}
              ]}
           ] ==
             Md.parse(">line 1\n>_______\n>line 2").ast

    assert [{:blockquote, nil, [{:p, nil, ["line 1"]}, {:hr, nil, []}, {:p, nil, ["line 2"]}]}] ==
             Md.parse(">line 1\n>---\>line 2").ast
  end

  test "nested paragraph" do
    input = """
    > This is a header.
    >
    > > This is the 1st line of nested quote.
    > > This is the 2ns line of nested quote.
    > This is the quote.

    Here's some example code:
    """

    assert [
             {:blockquote, nil,
              [
                {:p, nil, ["This is a header."]},
                {:p, nil,
                 [
                   {:blockquote, nil,
                    [
                      {:p, nil,
                       [
                         "This is the 1st line of nested quote.",
                         "\nThis is the 2ns line of nested quote."
                       ]}
                    ]},
                   "This is the quote."
                 ]}
              ]},
             {:p, nil, ["Here's some example code:"]}
           ] == Md.parse(input).ast
  end

  test "markdown in nested paragraph" do
    input = """
    > ## This is a header.
    >
    > 1.   This is the first list item.
    > 2.   This is the second list item.
    >
    > Here's some example code:
    >
    >     defmodule Foo do
    >       def yo!, do: :ok
    >     end
    >
    > Cool code, ain’t it?
    """

    assert [
             {
               :blockquote,
               nil,
               [
                 {:p, nil,
                  [
                    {:h2, nil, ["This is a header."]},
                    "\n",
                    {:ol, nil,
                     [
                       {:li, nil, ["This is the first list item."]},
                       {:li, nil, ["This is the second list item."]}
                     ]},
                    "\nHere's some example code:"
                  ]},
                 {:p, nil,
                  [
                    {:div, %{class: "pre"},
                     [
                       {:code, %{class: "pre"},
                        [" defmodule Foo do", "\n   def yo!, do: :ok", "\n end"]}
                     ]},
                    "Cool code, ain’t it?"
                  ]}
               ]
             }
           ] == Md.parse(input).ast
  end

  test "pairs (link)" do
    input = """
    Hi,

    check this [link](https://example.com/~derek/img_1.jpg)!
    """

    assert [
             {:p, nil, ["Hi,"]},
             {:p, nil,
              [
                "check this ",
                {:a, %{href: "https://example.com/~derek/img_1.jpg"}, ["link"]},
                "!"
              ]}
           ] == Md.parse(input).ast
  end

  test "pairs (img)" do
    input = """
    Hi,

    check this ![some_title](https://example.com)!

    and this: !![removed ~title~](https://example.com)!
    """

    assert [
             {:p, nil, ["Hi,"]},
             {:p, nil,
              ["check this ", {:img, %{src: "https://example.com", title: "some_title"}, []}, "!"]},
             {:p, nil,
              [
                "and this: ",
                {:figure, nil,
                 [
                   {:figcaption, nil, ["removed ", {:s, nil, ["title"]}]},
                   {:img, %{src: "https://example.com"}, []}
                 ]},
                "!"
              ]}
           ] == Md.parse(input).ast
  end

  test "deferred pairs" do
    input = """
    Hi,

    check this [link][1]!

    Another [text].

    [1]: https://example.com
    [2]: https://example.com
    """

    assert [
             {:p, nil, ["Hi,"]},
             {:p, nil, ["check this ", {:a, %{href: "https://example.com"}, ["link"]}, "!"]},
             {:p, nil, ["Another [text].", "\n", "\n[2]: https://example.com"]}
           ] == Md.parse(input).ast
  end

  # test "deferred footnotes" do
  #   input = """
  #   Hi, check[^1] this!

  #   [^1]: https://example.com
  #   [^2]: https://example.com
  #   """

  #   assert [
  #            {:p, nil, ["Hi,"]},
  #            {:p, nil, ["check this ", {:a, %{href: " https://example.com"}, ["link"]}, "!"]},
  #            {:p, nil, ["Another [text].", "\n", "\n", "[2]: https://example.com"]}
  #          ] == Md.parse(input).ast
  # end

  test "tables" do
    input = """
    Hi,

    | Item         | Price | # In stock |
    |--------------|:-----:|-----------:|
    | Juicy Apples |  1.99 |        739 |
    | **Bananas**  |  1.89 |          6 |
    """

    assert [
             {:p, nil, ["Hi,"]},
             {:table, nil,
              [
                {:tr, nil,
                 [
                   {:th, nil, [" Item         "]},
                   {:th, nil, [" Price "]},
                   {:th, nil, [" # In stock "]}
                 ]},
                {:tr, nil,
                 [
                   {:td, nil, [" Juicy Apples "]},
                   {:td, nil, ["  1.99 "]},
                   {:td, nil, ["        739 "]}
                 ]},
                {:tr, nil,
                 [
                   {:td, nil, [{:strong, %{class: "red"}, ["Bananas"]}, "  "]},
                   {:td, nil, ["  1.89 "]},
                   {:td, nil, ["          6 "]}
                 ]}
              ]}
           ] == Md.parse(input).ast
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
                  {:b, nil, ["foo ", {:strong, %{class: "red"}, ["bar"]}, "\nbaz"]},
                  " 42"
                ]},
               {:blockquote, nil, [{:p, nil, ["Hi, ", {:b, nil, ["there"]}, "olala"]}]},
               {:blockquote, nil,
                [
                  {:p, nil,
                   [
                     "Hi, ",
                     {:figure, nil,
                      [{:figcaption, nil, ["image"]}, {:img, %{src: "https://image.com"}, []}]},
                     "\n",
                     {:blockquote, nil,
                      [
                        {:p, nil,
                         [
                           "2nd ",
                           {:b, nil, ["1st"]},
                           " line",
                           "\n2nd ",
                           {:code, %{class: "code-inline"}, ["2nd"]},
                           " line"
                         ]}
                      ]},
                     "boom"
                   ]}
                ]},
               {:ul, nil,
                [
                  {:li, nil, ["1 | ", {:b, nil, ["foo"]}, " foo"]},
                  {:li, nil, ["1 | bar ", {:i, nil, ["bar"]}]},
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
                [{:code, %{class: "elixir"}, ["def foo, do: :ok\n\ndef bar, do: :error\n"]}]},
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
             ]
           }
  end
end
