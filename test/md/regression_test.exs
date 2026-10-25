defmodule Md.RegressionTest do
  @moduledoc """
  Regression tests for defects found in the full project audit.

  Each `describe` block pins one defect; the block name matches the audit
  section so the intent stays traceable. These tests intentionally exercise
  *public* API only (`Md.parse/2`, `Md.generate/2`) — the engine internals are
  free to change as long as the observable behaviour holds.
  """
  use ExUnit.Case, async: true

  # `format: :none` keeps assertions readable; caller options (e.g. `walker:`)
  # are merged on top rather than replacing it.
  defp html(input, options \\ []),
    do: Md.generate(input, Keyword.put_new(options, :format, :none))

  describe "§3.1 deferred reference links" do
    test "a deferred link resolves its href and emits no internal node" do
      assert html("[a][1]\n\n[1]: https://e.com") ==
               "<a href=\"https://e.com\">a</a>"
    end

    test "a named deferred reference resolves" do
      assert html("[click][abc]\n\n[abc]: https://e.com") ==
               "<a href=\"https://e.com\">click</a>"
    end

    test "the resolved AST contains no __deferred__ bookkeeping" do
      ast = Md.parse("[a][1]\n\n[1]: https://e.com").ast

      assert ast == [{:a, %{href: "https://e.com"}, ["a"]}]
      refute inspect(ast) =~ "__deferred__"
    end

    test "an unresolved deferred link falls back to the literal text" do
      assert html("[a][1]") =~ "a"
      refute html("[a][1]") =~ "__deferred__"
    end
  end

  describe "§3.2 footnotes" do
    test "an inline footnote renders a superscript anchor" do
      assert html("Check this[^1] out.") ==
               "<p>Check this<a href=\"#1\"><sup>1</sup></a> out.</p>"
    end

    test "a footnote with its definition resolves the href" do
      assert html("Check this[^1] out.\n\n[^1]: The note.") ==
               "<p>Check this<a href=\"#1\"><sup>1</sup></a> out.</p>"
    end

    test "a multi-character footnote label resolves" do
      assert html("x[^abc] y") == "<p>x<a href=\"#abc\"><sup>abc</sup></a> y</p>"
    end

    test "the footnote AST carries no raw map in an attribute" do
      assert [{:p, nil, [_, {:a, attrs, [{:sup, nil, ["1"]}]}, _]}] =
               Md.parse("Check this[^1] out.").ast

      assert is_binary(attrs[:href])
    end
  end

  describe "§4.1 attribute allow-list / XSS" do
    test "event-handler attributes are dropped by default" do
      assert html(~s|text{{onmouseover: "alert(1)"}}|) == "<p>text</p>"
    end

    test "event-handler attributes are dropped on inline elements" do
      assert html(~s|*b*{{onclick: "x"}}|) == "<p><b>b</b></p>"
    end

    test "event-handler attributes are dropped on links" do
      assert html(~s|[x {{onclick: "alert(1)"}}](y)|) == "<a href=\"y\">x </a>"
    end

    test "javascript: URIs are stripped from href" do
      assert html("[click](javascript:alert)") == "<a href=\"\">click</a>"
    end

    test "javascript: URIs are stripped from src" do
      assert html("![alt](javascript:alert)") =~ ~s|src=""|
    end

    test "safe attributes are still applied" do
      assert html(~s|text{{class: "p" data-x: y}}|) ==
               "<p class=\"p\" data-x=\"y\">text</p>"
    end

    test "a custom allow-list can be configured" do
      defmodule CustomAllowlistParser do
        use Md.Parser

        @syntax Md.Parser.Syntax.merge(%{
                  settings: %{attribute_allowlist: [:class, :id, :"data-role"]}
                })
      end

      # Attribute order in the output is not part of the contract.
      out =
        Md.generate(~s|t{{class: "a" id: "b" rel: "c"}}|,
          parser: CustomAllowlistParser,
          format: :none
        )

      assert out =~ ~s|class="a"|
      assert out =~ ~s|id="b"|
      refute out =~ "rel"
    end

    test "event handlers are refused even when filtering is disabled" do
      defmodule PermissiveParser do
        use Md.Parser

        @syntax Md.Parser.Syntax.merge(%{
                  settings: %{attribute_allowlist: :all}
                })
      end

      # `:all` lifts the allow-list, but `on*` is never a legitimate attribute
      # and stays refused: disabling filtering must not turn the parser into an
      # XSS vector by accident.
      assert Md.generate(~s|t{{onclick: "x"}}|, parser: PermissiveParser, format: :none) ==
               "<p>t</p>"

      assert Md.generate(~s|t{{title: "x"}}|, parser: PermissiveParser, format: :none) ==
               "<p title=\"x\">t</p>"
    end
  end

  describe "§4.2 atom-table safety" do
    test "unknown attribute names do not intern new atoms" do
      before = :erlang.system_info(:atom_count)

      for i <- 1..200 do
        Md.parse("*x*{{audit_probe_#{i}: v}}")
      end

      assert :erlang.system_info(:atom_count) - before < 20
    end
  end

  describe "§4.3 walker contract" do
    test "a walker returning nil drops every node instead of emitting `</>`" do
      # `XmlBuilder` renders a bare `nil` node as `</>`, which is never what a
      # caller means by "drop this node".
      assert html("*x*", walker: fn _ -> nil end) == ""
    end

    test "an identity walker yields the same XML" do
      assert html("*x*", walker: & &1) == "<p><b>x</b></p>"
    end

    test "an arity-2 walker returns {xml, accumulator}" do
      assert {xml, %{}} =
               Md.generate("*x*", walker: fn node, acc -> {node, acc} end, format: :none)

      assert xml == "<p><b>x</b></p>"
    end
  end

  describe "§4.4 unclosed pairs recover" do
    test "an unclosed link does not reorder its content" do
      assert html("[foo](bar") == "<p>[foo](bar</p>"
    end

    test "an unclosed deferred link stays literal" do
      assert html("[foo][bar") == "<p>[foo][bar</p>"
    end

    test "an unclosed image stays literal" do
      assert html("![alt](x.png") == "<p>![alt](x.png</p>"
    end

    test "attributes inside a pair's display text cannot inject a handler" do
      # `{{…}}` inside `![…]` has no element to attach to. The markup is not
      # reproduced faithfully, but the security property must hold: the
      # handler never reaches the output.
      refute html(~s|![alt {{onerror: "alert(1)"}}](x.png)|) =~ "onerror"
    end
  end

  describe "§5.5 URL magnet terminators" do
    test "a trailing period is not swallowed into the href" do
      assert html("see https://example.com/foo.") ==
               "<p>see <a href=\"https://example.com/foo\">https://example.com/foo</a>.</p>"
    end

    test "a trailing comma is not swallowed into the href" do
      assert html("see https://example.com/foo, ok") ==
               "<p>see <a href=\"https://example.com/foo\">https://example.com/foo</a>, ok</p>"
    end

    test "a closing parenthesis is not swallowed into the href" do
      assert html("(https://example.com/foo)") ==
               "<p>(<a href=\"https://example.com/foo\">https://example.com/foo</a>)</p>"
    end

    test "balanced parentheses inside a URL are preserved" do
      assert html("[a](https://e.com/a(b))") ==
               "<a href=\"https://e.com/a(b)\">a</a>"
    end
  end

  describe "§5.10 whitespace-only input" do
    test "whitespace-only input yields no output" do
      assert html("   \n\n  ") == ""
      assert Md.parse("   \n\n  ").ast == []
    end
  end

  describe "§5.1 Md.parse/1 return type" do
    test "parse/1 always returns a state struct, never a tuple" do
      assert %Md.Parser.State{} = Md.parse("x")
      assert %Md.Parser.State{} = Md.parse("x", Md.with(Md.Parser.Default))
    end
  end

  describe "§5.2 DSL settings" do
    test "several settings declarations compose without nesting" do
      defmodule MultiSettingsParser do
        use Md.Parser, dsl: true
        import Md.Parser.DSL

        outer(:article)
        span(:div)
        linewrap true
      end

      settings = MultiSettingsParser.syntax()[:settings]

      assert settings[:outer] == :article
      assert settings[:span] == :div
      assert settings[:linewrap] == true
      refute Map.has_key?(settings, :settings)
    end
  end
end
