defmodule Md.Parser.DSL do
  @moduledoc false

  alias Md.Parser.Syntax

  Enum.each(Syntax.types(), fn type ->
    defmacro unquote(type)(opening, attrs) do
      quote generated: true,
            location: :keep,
            bind_quoted: [type: unquote(type), opening: opening, attrs: attrs] do
        @syntax %{type => [{opening, attrs}]}
      end
    end
  end)

  defmacro linewrap(value \\ true) do
    quote do
      @syntax %{linewrap: unquote(value)}
    end
  end
end
