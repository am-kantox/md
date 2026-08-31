defmodule Md.Engine.Test do
  use ExUnit.Case
  doctest Md.Engine

  defmodule RawBlockParser do
    @moduledoc false
    use Md.Parser

    alias Md.Parser.Syntax.Default

    @syntax Md.Parser.Syntax.merge(
              %{block: [{"@@@", %{tag: :raw_embed, escape: false}}]},
              Map.put(Default.syntax(), :settings, Default.settings())
            )
  end

  describe "block/1 escape option" do
    test "block content is HTML-entity-escaped by default (existing behavior, unchanged)" do
      input = "```\n<a href=\"x\">y</a> & 'z'\n```"

      assert [{:pre, nil, [{:code, nil, [content]}]}] = Md.parse(input).ast
      assert content == "&lt;a href=&quot;x&quot;&gt;y&lt;/a&gt; &amp; &#39;z&#39;\n"
    end

    test "block content is carried verbatim when escape: false is set" do
      input = "@@@\n<a href=\"x\">y</a> & 'z'\n@@@"

      assert {"", %{ast: [{:raw_embed, nil, [content]}]}} = RawBlockParser.parse(input)
      assert content == "<a href=\"x\">y</a> & 'z'\n"
    end
  end

  test "closing_match/1" do
    assert [
             {:{}, [], [:c, {:_, [], Md.Engine.Test}, {:_, [], Md.Engine.Test}]},
             {:{}, [], [:b, {:_, [], Md.Engine.Test}, {:_, [], Md.Engine.Test}]},
             {:{}, [], [:a, {:_, [], Md.Engine.Test}, {:_, [], Md.Engine.Test}]}
           ] = Md.Engine.closing_match([:a, :b, :c], __MODULE__)
  end

  test "raises when no @syntax defined" do
    message =
      if Version.match?(System.version(), ">= 1.15.0") do
        "`@syntax` must be set or passed to `use Md.Parser` as `syntax:`"
      else
        " `@syntax` must be set or passed to `use Md.Parser` as `syntax:`"
      end

    assert_raise CompileError,
                 message,
                 fn ->
                   Module.create(NoSyntax, quote(do: use(Md.Parser)), Macro.Env.location(__ENV__))
                 end
  end
end
