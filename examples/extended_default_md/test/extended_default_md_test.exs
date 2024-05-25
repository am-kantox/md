defmodule ExtendedDefaultMdTest do
  use ExUnit.Case
  doctest ExtendedDefaultMd

  test "knows about `==` from config" do
    assert [{:p, nil, ["I am ", {:b, %{color: :red}, ["red"]}, ", are you?"]}] == Md.parse("I am ==red==, are you?").ast
  end

  test "remembers about all the defaults" do
    assert [{:p, nil, ["I am ", {:strong, %{class: "red"}, ["bold"]}, ", are you?"]}] == Md.parse("I am **bold**, are you?").ast
  end
end
