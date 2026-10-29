defmodule Md.ContractProbe do
  @moduledoc false

  # Compiled in both test and CI environments so Dialyzer checks the same
  # success paths that the runtime tests exercise. An error-only/no-return
  # parser typing or a node-only deferred contract makes these patterns fail.
  @spec resolve_document(binary()) :: binary()
  def resolve_document(value) do
    [resolved] = Md.Deferred.apply([{:__deferred__, "ref", ["fallback"]}], [{"ref", value}])
    resolved
  end

  @spec parse_document(binary()) :: [Md.Listener.branch()]
  def parse_document(input) do
    {"", %Md.Parser.State{ast: ast}} = Md.Parser.Default.parse(input)
    ast
  end

  @spec flatten_text(binary()) :: binary()
  def flatten_text(text), do: Md.Engine.flatten(text)

  @spec flatten_node(Md.Listener.branch()) :: binary()
  def flatten_node(node), do: Md.Engine.flatten(node)
end
