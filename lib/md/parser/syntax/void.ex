defmodule Md.Parser.Syntax.Void do
  @moduledoc false

  alias Md.Parser.Syntax

  @behaviour Syntax

  @impl Syntax
  def settings do
    %{
      outer: :p,
      span: :span,
      empty_tags: ~w|img hr br|a
    }
  end

  @impl Syntax
  def syntax,
    do: Syntax.types() |> Enum.zip(Stream.cycle([[]])) |> Map.new()
end
