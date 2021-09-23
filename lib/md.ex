defmodule Md do
  @moduledoc """
  Documentation for `Md`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Md.parse("   foo")
      %Md.Parser.State{ast: [{:p, [], ["foo"]}], path: []}

  """
  defdelegate parse(input), to: Md.Parser
  defdelegate generate(input), to: Md.Parser
end
