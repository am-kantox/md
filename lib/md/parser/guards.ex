defmodule Md.Guards do
  @moduledoc """
  Several guards for the proper UTF8 handling of input.
  """

  [digits, punctuation, spaces] =
    [~r/digit/i, ~r/punct/i, ~r/space/i]
    |> Enum.map(fn re ->
      re
      |> StringNaming.graphemes(false)
      |> Enum.map_join(&elem(&1, 1))
      |> to_charlist()
    end)

  punctuation = punctuation -- '_'
  spaces = [?\n, ?\r | spaces]

  defguard is_utf8_space(char) when char in unquote(spaces)
  defguard is_utf8_punct(char) when char in unquote(punctuation)
  defguard is_utf8_digit(char) when char in unquote(digits)
end
