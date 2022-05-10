defmodule Md.Parser.Test do
  use ExUnit.Case

  doctest Md.Parser

  test "inspect/2" do
    assert ~s|#Md<[path: [], ast: [], payload: nil, internals: [mode: [:idle], indent: [], stock: [], deferred: []]]>| ==
             inspect(%Md.Parser.State{})
  end
end
