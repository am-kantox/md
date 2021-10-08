defmodule MdParserTest do
  use ExUnit.Case

  doctest Md.Parser
  import ExUnit.CaptureIO

  test "inspect/2" do
    assert ~s|#Md<[\n  path: [],\n  ast: [],\n  internals: [mode: [:idle], indent: [], stock: [], deferred: []]\n]>\n| ==
             capture_io(fn ->
               IO.inspect(%Md.Parser.State{})
             end)
  end
end
