defmodule Md.Engine.Test do
  use ExUnit.Case
  doctest Md.Engine

  test "closing_match/1" do
    assert [
             {:{}, [], [:c, {:_, [], nil}, {:_, [], nil}]},
             {:{}, [], [:b, {:_, [], nil}, {:_, [], nil}]},
             {:{}, [], [:a, {:_, [], nil}, {:_, [], nil}]}
           ] = Md.Engine.closing_match([:a, :b, :c])
  end

  test "raises when no @syntax defined" do
    assert_raise CompileError,
                 " `@syntax` must be set or passed to `use Md.Parser` as `syntax:`",
                 fn ->
                   Module.create(NoSyntax, quote(do: use(Md.Parser)), Macro.Env.location(__ENV__))
                 end
  end
end
