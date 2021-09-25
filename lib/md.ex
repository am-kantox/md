defmodule Md do
  @moduledoc """
  Documentation for `Md`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Md.parse("   foo")
      %Md.Parser.State{ast: [{:p, [], ["foo"]}], listener: Md.Parser.DebugListener}

  """
  defdelegate parse(input), to: Md.Parser
  defdelegate parse(input, listener), to: Md.Parser
  defdelegate generate(input), to: Md.Parser
  defdelegate generate(input, options), to: Md.Parser
end
