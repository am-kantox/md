defmodule Md.DeferredTest do
  use ExUnit.Case, async: true

  alias Md.ContractProbe
  alias Md.Deferred

  test "resolves a whole document list without discarding surrounding nodes" do
    ast = [
      {:p, nil, ["before"]},
      {:__deferred__, "ref", ["fallback"]},
      {:p, nil, ["after"]}
    ]

    assert Deferred.apply(ast, [{"ref", "resolved"}]) == [
             {:p, nil, ["before"]},
             "resolved",
             {:p, nil, ["after"]}
           ]

    assert ContractProbe.resolve_document("resolved") == "resolved"
  end

  test "supports an empty document, text leaves and individual nodes" do
    assert Deferred.apply([], []) == []
    assert Deferred.apply("text", []) == "text"
    assert Deferred.apply({:__deferred__, "missing", ["fallback"]}, []) == "fallback"
  end

  test "resolves nested attributes within a document list" do
    ast = [
      {:p, nil,
       [
         {:a, %{__deferred__: %{attribute: :href, content: "ref"}}, ["link"]}
       ]}
    ]

    assert Deferred.apply(ast, [{"ref", "https://example.com"}]) == [
             {:p, nil, [{:a, %{href: "https://example.com"}, ["link"]}]}
           ]
  end

  test "generated parser finalization returns a document AST" do
    assert ContractProbe.parse_document("") == []
    assert ContractProbe.parse_document("plain text") == [{:p, nil, ["plain text"]}]

    assert ContractProbe.parse_document("[link][ref]\n\n[ref]: https://example.com") == [
             {:a, %{href: "https://example.com"}, ["link"]}
           ]
  end

  test "flatten supports both scalar fragments and document lists" do
    assert ContractProbe.flatten_text("plain") == "plain"
    assert ContractProbe.flatten_node({:b, nil, ["bold"]}) == "bold"
    assert Md.Engine.flatten(["before", {:b, nil, ["bold"]}, "after"]) == "beforeboldafter"
  end
end
