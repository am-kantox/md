defmodule Md do
  @moduledoc """
  Documentation for `Md`.
  """

  @behaviour Md.Parser

  alias Md.Parser.Default, as: Parser

  @doc """
  Interface to the library. Use `parse/2` to parse the input to the state,
  use `generate/{1,2}` to produce an _HTML_ out of the input.

  ## Examples

      iex> Md.parse("   foo")
      %Md.Parser.State{ast: [{:p, nil, ["foo"]}], mode: [:finished]}

      iex> Md.generate("It’s all *bold* and _italic_!", format: :none)
      "<p>It’s all <b>bold</b> and <it>italic</it>!</p>"

  """
  def parse(input, listener \\ nil),
    do: with({"", state} <- Parser.parse(input, listener), do: state)

  defdelegate generate(input), to: Md.Parser
  defdelegate generate(input, options), to: Md.Parser
end
