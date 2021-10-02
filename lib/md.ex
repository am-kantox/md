defmodule Md do
  @moduledoc """
  Documentation for `Md`.
  """

  @behaviour Md.Parser

  @doc """
  Interface to the library.

  ## Examples

      iex> Md.parse("   foo")
      %Md.Parser.State{ast: [{:p, nil, ["foo"]}], listener: Md.Listener.Debug, mode: [:finished]}

  """
  defdelegate parse(input), to: Md.Parser.Default
  defdelegate parse(input, listener), to: Md.Parser.Default
  defdelegate generate(input), to: Md.Parser
  defdelegate generate(input, options), to: Md.Parser
end
