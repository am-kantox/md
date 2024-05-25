defmodule Md do
  @mdoc "README.md" |> File.read!() |> String.split("---\n") |> Enum.at(1)
  @moduledoc """
  `Md` is a markup parser allowing fully customized syntax definition and
  understanding the wide range of [markdown](https://www.markdownguide.org/) out of the box.

  It is stream-aware, extendable, flexible, blazingly fast, with callbacks and more.

  #{@mdoc}
  """

  @behaviour Md.Parser

  alias Md.Parser.State, as: State

  @doc """
  Interface to the library. Use `parse/2` to parse the input to the state,
  use `generate/{1,2}` to produce an _HTML_ out of the input.

  ## Examples

      iex> Md.parse("   foo")
      %Md.Parser.State{ast: [{:p, nil, ["foo"]}], mode: [:finished]}

      iex> Regex.replace(~r/\\s+/, Md.generate("*bold*"), "")
      "<p><b>bold</b></p>"

      iex> Md.generate("It’s all *bold* and _italic_!", Md.Parser.Default, format: :none)
      "<p>It’s all <b>bold</b> and <i>italic</i>!</p>"

  """
  @impl Md.Parser
  def parse(input, state \\ %State{}),
    do: with({"", state} <- state.type.parse(input, state), do: state)

  @doc """
  Helper function to supply a custom parser in call to `Md.parse/2` as

  ```elixir
  Md.parse("some _text_ with *markup*", Md.with(Md.Parser.Default))
  ```
  """
  def with(parser) do
    %Md.Parser.State{type: parser}
  end

  defdelegate generate(input), to: Md.Parser
  defdelegate generate(input, options), to: Md.Parser
  defdelegate generate(input, parser, options), to: Md.Parser
end
