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

  Enum.each(Syntax.settings(), fn type ->
    defmacro unquote(type)(setting) do
      quote bind_quoted: [type: unquote(type), setting: setting] do
        @syntax %{
          settings:
            Map.put(
              Enum.find(@syntax, Md.Parser.Syntax.Void.settings(), &match?(%{settings: _}, &1)),
              type,
              setting
            )
        }
      end
    end
  end)
end
