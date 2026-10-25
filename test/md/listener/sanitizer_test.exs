defmodule Md.Listener.SanitizerTest do
  use ExUnit.Case, async: true

  alias Md.Listener.Sanitizer

  describe "sanitize/2" do
    test "keeps allowed elements and their content" do
      ast = [{:p, nil, [{:b, nil, ["bold"]}, " and ", {:sup, nil, ["2"]}]}]
      assert Sanitizer.sanitize(ast) == ast
    end

    test "unwraps a disallowed element but keeps its content" do
      assert Sanitizer.sanitize([{:script, %{}, ["alert(1)"]}]) == ["alert(1)"]
    end

    test "unwraps a disallowed element nested inside an allowed one" do
      assert Sanitizer.sanitize([{:p, nil, [{:script, %{}, ["x"]}, "y"]}]) ==
               [{:p, nil, ["x", "y"]}]
    end

    test "strips event-handler attributes" do
      assert Sanitizer.sanitize([{:p, %{onclick: "x", class: "y"}, ["hi"]}]) ==
               [{:p, %{class: "y"}, ["hi"]}]
    end

    test "strips attributes carrying an executable URI scheme" do
      assert Sanitizer.sanitize([{:a, %{href: "javascript:alert(1)"}, ["x"]}]) ==
               [{:a, %{}, ["x"]}]
    end

    test "keeps attributes carrying a safe URI scheme" do
      ast = [{:a, %{href: "https://example.com"}, ["x"]}]
      assert Sanitizer.sanitize(ast) == ast
    end

    test "an explicit allow-list narrows the kept attributes" do
      assert Sanitizer.sanitize(
               [{:p, %{class: "y", id: "z"}, ["hi"]}],
               %{allowed_attributes: [:class]}
             ) == [{:p, %{class: "y"}, ["hi"]}]
    end

    test "an explicit tag list narrows the kept elements" do
      assert Sanitizer.sanitize(
               [{:p, nil, [{:b, nil, ["x"]}]}],
               %{allowed_tags: [:p]}
             ) == [{:p, nil, ["x"]}]
    end

    test "plain text passes through untouched" do
      assert Sanitizer.sanitize(["a", "b"]) == ["a", "b"]
    end
  end

  describe "as a parser listener" do
    test "sanitises the AST produced by a permissive parser" do
      defmodule PermissiveParser do
        use Md.Parser

        @syntax Md.Parser.Syntax.merge(%{
                  settings: %{attribute_allowlist: :all},
                  tag: [{"script", %{}}]
                })
      end

      state = %Md.Parser.State{type: PermissiveParser, listener: Sanitizer}

      ast = Md.parse("<script>alert(1)</script>", state).ast

      refute inspect(ast) =~ ":script"
      assert inspect(ast) =~ "alert(1)"
    end

    test "leaves ordinary markup alone" do
      state = %Md.Parser.State{listener: Sanitizer}
      assert Md.parse("*bold*", state).ast == [{:p, nil, [{:b, nil, ["bold"]}]}]
    end
  end
end
