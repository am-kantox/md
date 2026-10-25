defmodule Md.PropertyTest do
  @moduledoc """
  Property-based tests.

  These pin the invariants that the audit's defects violated, over generated
  input rather than hand-picked examples. Every one of the Phase 1 bugs would
  have been caught by the "never raises" and "no internal bookkeeping escapes"
  properties below.
  """
  use ExUnit.Case, async: true

  use ExUnitProperties

  alias Md.Listener.Sanitizer

  # Markup-ish fragments, biased towards the characters that drive the parser's
  # dispatch: markers, brackets, delimiters and the two line-break forms.
  @fragments [
    "*",
    "**",
    "_",
    "~~",
    "`",
    "``",
    "[",
    "]",
    "(",
    ")",
    "![",
    "!![",
    "?[",
    "[^",
    "{",
    "}",
    "{{",
    "}}",
    "|",
    "-",
    "---",
    "#",
    "##",
    ">",
    "@",
    "~",
    "\\",
    "<",
    "&",
    "sup",
    "kbd",
    ":",
    ";",
    ".",
    ",",
    "!",
    "?",
    "\n",
    "\r\n",
    "\n\n",
    "  \n",
    "    ",
    "\t",
    " ",
    "word",
    "日本",
    "👋",
    "https://e.com",
    "https://e.com/a(b)",
    "javascript:alert(1)",
    "onclick",
    "class",
    "x"
  ]

  defp fragment, do: member_of(@fragments)

  defp document do
    gen all(fragments <- list_of(fragment(), min_length: 0, max_length: 40)) do
      Enum.join(fragments)
    end
  end

  defp html(input), do: Md.generate(input, format: :none)

  property "parsing never raises, whatever the input" do
    check all(input <- document(), max_runs: 500) do
      assert %Md.Parser.State{} = Md.parse(input)
    end
  end

  property "rendering never raises, whatever the input" do
    check all(input <- document(), max_runs: 500) do
      assert is_binary(html(input))
    end
  end

  property "no internal bookkeeping reaches the output" do
    check all(input <- document(), max_runs: 500) do
      output = html(input)

      refute output =~ "__deferred__"
      refute output =~ "__pair__"
      refute output =~ "</>"
    end
  end

  property "no internal bookkeeping survives into the AST" do
    check all(input <- document(), max_runs: 500) do
      refute inspect(Md.parse(input).ast) =~ "__deferred__"
    end
  end

  property "event handlers never reach the output" do
    check all(input <- document(), max_runs: 500) do
      refute html(input) =~ ~r/\son[a-z]+\s*=/i
    end
  end

  property "executable URI schemes never reach a URI attribute" do
    check all(input <- document(), max_runs: 500) do
      # Only *attributes* matter: `javascript:alert(1)` as plain text is just
      # text and must be preserved verbatim.
      refute html(input) =~ ~r/(href|src)="\s*javascript:/i
    end
  end

  property "rendering is deterministic" do
    check all(input <- document(), max_runs: 200) do
      assert html(input) == html(input)
    end
  end

  property "whitespace-only input renders to nothing" do
    check all(
            ws <- list_of(member_of([" ", "\t", "\n", "\r\n"]), min_length: 1, max_length: 20),
            max_runs: 200
          ) do
      assert html(Enum.join(ws)) == ""
    end
  end

  property "a resolved deferred reference carries no placeholder" do
    check all(
            label <- string(:alphanumeric, min_length: 1, max_length: 8),
            url <- member_of(["https://e.com", "http://a.b/c", "https://e.com/x(y)"]),
            max_runs: 200
          ) do
      assert html("[text][#{label}]\n\n[#{label}]: #{url}") ==
               "<a href=\"#{url}\">text</a>"
    end
  end

  property "a footnote always renders as an in-page anchor" do
    check all(label <- string(:alphanumeric, min_length: 1, max_length: 8), max_runs: 200) do
      assert html("x[^#{label}] y") ==
               "<p>x<a href=\"##{label}\"><sup>#{label}</sup></a> y</p>"
    end
  end

  property "auto-linked URLs never absorb trailing sentence punctuation" do
    check all(
            path <- string(:alphanumeric, min_length: 1, max_length: 8),
            punct <- member_of([".", ",", ";", ":", "!", "?", ")"]),
            max_runs: 200
          ) do
      assert html("see https://e.com/#{path}#{punct}") ==
               "<p>see <a href=\"https://e.com/#{path}\">https://e.com/#{path}</a>#{punct}</p>"
    end
  end

  property "sanitising is idempotent" do
    check all(input <- document(), max_runs: 300) do
      once = Sanitizer.sanitize(Md.parse(input).ast)
      twice = Sanitizer.sanitize(once)

      assert once == twice
    end
  end

  property "sanitising never leaves a handler or an executable URI attribute" do
    check all(input <- document(), max_runs: 300) do
      ast = Sanitizer.sanitize(Md.parse(input).ast)

      # Inspect attributes only: `javascript:alert(1)` as *text* is fine and
      # must survive.
      attrs =
        ast
        |> collect_attributes()
        |> Enum.map_join(" ", fn {k, v} -> "#{k}=#{inspect(v)}" end)

      refute attrs =~ ~r/\bon[a-z]+=/i

      # Only the *scheme* matters: `https://e.comjavascript:alert(1)` is a
      # perfectly ordinary `https` URL whose path happens to contain the word.
      refute Enum.any?(collect_attributes(ast), fn {_k, v} ->
               is_binary(v) and
                 match?(
                   %URI{scheme: s} when s in ["javascript", "data", "vbscript"],
                   URI.parse(v)
                 )
             end)
    end
  end

  defp collect_attributes(ast) when is_list(ast),
    do: Enum.flat_map(ast, &collect_attributes/1)

  defp collect_attributes({_tag, attrs, content}) when is_map(attrs),
    do: Map.to_list(attrs) ++ collect_attributes(content)

  defp collect_attributes({_tag, _attrs, content}), do: collect_attributes(content)
  defp collect_attributes(_), do: []
end
