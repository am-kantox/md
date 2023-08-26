defmodule Md.Parser.Syntax.Void do
  @moduledoc """
  Void syntax to be extended by custom implementations. Included for convenience.
  """

  alias Md.Parser.Syntax

  @behaviour Syntax

  @impl Syntax
  @doc """
  Returns default values for outer tag, span tag and empty tags.
  """
  def settings do
    %{
      outer: :p,
      span: :span,
      linebreaks: [<<?\r, ?\n>>, <<?\n>>],
      empty_tags: ~w|img hr br|a,
      requiring_attributes_tags: ~w|a|a,
      linewrap: false
    }
  end

  @impl Syntax
  @doc "Empty syntax"
  def syntax,
    do: Syntax.types() |> Enum.zip(Stream.cycle([[]])) |> Map.new()
end
