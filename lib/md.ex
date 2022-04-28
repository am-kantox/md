defmodule Md do
  @mdoc "README.md" |> File.read!() |> String.split("---\n") |> Enum.at(1)
  @moduledoc """
  `Md` is a markup parser allowing fully customized syntax definition and
  understanding the wide range of [markdown](https://www.markdownguide.org/) out of the box.

  It is stream-aware, extendable, flexible, blazingly fast, with callbacks and more.

  #{@mdoc}
  """

  @behaviour Md.Parser

  alias Md.Parser.Default, as: Parser
  alias Md.Parser.State, as: State

  @doc """
  Interface to the library. Use `parse/2` to parse the input to the state,
  use `generate/{1,2}` to produce an _HTML_ out of the input.

  ## Examples

      iex> Md.parse("   foo")
      %Md.Parser.State{ast: [{:p, nil, ["foo"]}], mode: [:finished]}

      iex> Regex.replace(~r/\\s+/, Md.generate("*bold*"), "")
      "<b>bold</b>"

      iex> Md.generate("It’s all *bold* and _italic_!", Md.Parser.Default, format: :none)
      "<p>It’s all <b>bold</b> and <i>italic</i>!</p>"

  """
  @impl Md.Parser
  def parse(input, state \\ %State{}),
    do: with({"", state} <- Parser.parse(input, state), do: state)

  defdelegate generate(input), to: Md.Parser
  defdelegate generate(input, parser, options), to: Md.Parser
end
