defmodule Md.Engine.Test do
  use ExUnit.Case
  doctest Md.Engine

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
