defmodule Md.Parser.DSL do
  @moduledoc false

  Enum.each(Md.Parser.Syntax.types(), fn type ->
    defmacro unquote(type)(opening, attrs) do
      quote bind_quoted: [type: unquote(type), opening: opening, attrs: attrs] do
        @syntax %{type => [{opening, attrs}]}
      end
    end
  end)

end
