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
        # `@syntax` is an accumulating attribute, so each declaration appends a
        # one-key map. The settings declarations must therefore read the
        # *current* settings map back out of the accumulated list and merge the
        # new key into it -- `Enum.find/3` would return the matching `{key,
        # value}` tuple, which is how the settings map ended up nested inside
        # itself under a `:settings` key.
        current =
          @syntax
          |> Enum.find_value(Md.Parser.Syntax.Void.settings(), fn
            %{settings: settings} when is_map(settings) -> settings
            _ -> nil
          end)

        @syntax %{settings: Map.put(current, type, setting)}
      end
    end
  end)
end
