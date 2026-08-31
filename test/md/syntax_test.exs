defmodule Md.Parser.SyntaxTest do
  use ExUnit.Case, async: true

  alias Md.Parser.Syntax
  alias Md.Parser.Syntax.Default

  describe "merge/2" do
    test "merges an ordinary category by prefix, sorted by descending length" do
      merged =
        Syntax.merge(%{magnet: [{"@@", %{transform: :fake}}]}, %{
          magnet: [{"@", %{transform: :other}}],
          settings: %{}
        })

      assert [{"@@", %{transform: :fake}}, {"@", %{transform: :other}}] == merged[:magnet]
    end

    test "does not crash when the custom map includes a :settings key" do
      custom = %{
        settings: %{outer: :section},
        magnet: [{"@", %{transform: :fake}}]
      }

      assert %{settings: settings} =
               Syntax.merge(custom, Map.put(Default.syntax(), :settings, Default.settings()))

      # The custom :settings value wins for the keys it sets, while
      # everything else from Default's own settings is preserved.
      assert settings.outer == :section
      assert settings.span == Default.settings().span
    end

    test ":settings remains a plain map, not a list of tuples, after merging" do
      merged =
        Syntax.merge(%{settings: %{linewrap: true}}, %{
          settings: Default.settings(),
          magnet: []
        })

      assert is_map(merged[:settings])
      refute is_list(merged[:settings])
      assert merged[:settings][:linewrap] == true
    end

    test "merging with no :settings key in either map still produces a usable syntax map" do
      merged = Syntax.merge(%{magnet: [{"@", %{transform: :fake}}]}, %{magnet: []})
      assert merged[:magnet] == [{"@", %{transform: :fake}}]
    end
  end
end
