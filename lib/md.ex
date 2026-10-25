defmodule Md do
  @mdoc "README.md" |> File.read!() |> String.split("---\n") |> Enum.at(1)
  @moduledoc """
  `Md` is a markup parser allowing fully customized syntax definition and
  understanding the wide range of [markdown](https://www.markdownguide.org/) out of the box.

  It is stream-aware, extendable, flexible, blazingly fast, with callbacks and more.

  #{@mdoc}
  """

  @behaviour Md.Parser

  alias Md.Listener, as: L
  alias Md.Parser.State, as: State

  @doc """
  Parses `input` into a `Md.Parser.State`, whose `:ast` field holds the
  document tree.

  The parser is selected by the `:type` field of `state`, so a custom syntax is
  supplied with `Md.with/1`:

  ```elixir
  Md.parse("some _text_", Md.with(MyParser))
  ```

  ## Examples

      iex> Md.parse("   foo")
      %Md.Parser.State{ast: [{:p, nil, ["foo"]}], mode: [:finished]}

      iex> Regex.replace(~r/\\s+/, Md.generate("*bold*"), "")
      "<p><b>bold</b></p>"

      iex> Md.generate("It’s all *bold* and _italic_!", Md.Parser.Default, format: :none)
      "<p>It’s all <b>bold</b> and <i>italic</i>!</p>"

  """
  @impl Md.Parser
  @spec parse(binary(), L.state()) :: L.state()
  def parse(input, state \\ %State{}) do
    {_rest, state} = state.type.parse(input, state)
    state
  end

  @doc """
  Helper function to supply a custom parser in call to `Md.parse/2` as

  ```elixir
  Md.parse("some _text_ with *markup*", Md.with(Md.Parser.Default))
  ```
  """
  @spec with(module()) :: State.t()
  def with(parser) do
    %Md.Parser.State{type: parser}
  end

  @doc "See `Md.Parser.generate/2`."
  @spec generate(binary() | L.state()) :: binary() | {binary(), any()}
  defdelegate generate(input), to: Md.Parser

  @doc "See `Md.Parser.generate/2`."
  @spec generate(binary() | L.state(), keyword()) :: binary() | {binary(), any()}
  defdelegate generate(input, options), to: Md.Parser

  @doc "See `Md.Parser.generate/3`."
  @spec generate(binary() | L.state(), module(), keyword()) :: binary() | {binary(), any()}
  defdelegate generate(input, parser, options), to: Md.Parser
end
