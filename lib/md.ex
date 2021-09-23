defmodule Md do
  @moduledoc """
  Documentation for `Md`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Md.parse("   foo")
      {:p, [], "foo"}

  """
  defdelegate parse(input), to: Md.Parser
  defdelegate generate(input), to: Md.Parser
end
