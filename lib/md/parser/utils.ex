defmodule Md.Utils do
  @moduledoc false

  alias Md.Listener, as: L

  @spec closing_match(L.branch()) :: Macro.t()
  def closing_match(tags) do
    us = Macro.var(:_, %Macro.Env{}.context)
    Enum.reduce(tags, [], &[{:{}, [], [&1, us, us]} | &2])
  end
end
