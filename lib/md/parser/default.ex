defmodule Md.Parser.Default do
  @moduledoc """
  Default parser with all the features included.

  Supports a wide subset of markdown, including but not limited to:

  - bold/italic/strikeout/etc text decorations
  - comments
  - code blocks
  - tables
  - twitter handlers etc

  Might be a good start for those who just needs a fast markdown processing.
  """

  use Md.Parser

  alias Md.Parser.Syntax.Default

  @default_syntax Map.put(Default.syntax(), :settings, Default.settings())
  @custom_syntax Application.compile_env(:md, :syntax, %{})
  @syntax @default_syntax
          |> Map.merge(@custom_syntax, fn
            _k, v1, v2 ->
              [v2, v1] |> Enum.map(&Map.new/1) |> Enum.reduce(&Map.merge/2) |> Map.to_list()
          end)
          |> Enum.map(fn
            {k, v} when is_list(v) ->
              {k, Enum.sort_by(v, &(-String.length(elem(&1, 0))))}

            {k, v} ->
              {k, v}
          end)
end
