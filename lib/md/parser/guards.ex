defmodule Md.Guards do
  @moduledoc """
  Several guards for the proper UTF8 handling of input.

  ## Examples

      iex> import Md.Guards
      iex> with <<x::utf8, _::binary>> <- " ", do: is_ascii_space(x)
      true
      iex> with <<x::utf8, _::binary>> <- " ", do: is_non_ascii_space(x)
      false
      iex> with <<x::utf8, _::binary>> <- " ", do: is_utf8_space(x)
      true
      iex> with <<x::utf8, _::binary>> <- "!", do: is_ascii_punct(x)
      true
      iex> with <<x::utf8, _::binary>> <- "!", do: is_non_ascii_punct(x)
      false
      iex> with <<x::utf8, _::binary>> <- "!", do: is_utf8_punct(x)
      true
      iex> with <<x::utf8, _::binary>> <- "1", do: is_ascii_digit(x)
      true
      iex> with <<x::utf8, _::binary>> <- "1", do: is_non_ascii_digit(x)
      false
      iex> with <<x::utf8,_::binary>> <- "①", do: is_utf8_digit(x)
      true
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

  {ascii_spaces, non_ascii_spaces} = Enum.split_with(spaces, &(&1 < 128))
  {ascii_punctuation, non_ascii_punctuation} = Enum.split_with(punctuation, &(&1 < 128))
  {ascii_digits, non_ascii_digits} = Enum.split_with(digits, &(&1 < 128))

  defguard is_ascii_space(char) when char in unquote(ascii_spaces)
  defguard is_non_ascii_space(char) when char in unquote(non_ascii_spaces)
  defguard is_utf8_space(char) when char in unquote(spaces)
  defguard is_ascii_punct(char) when char in unquote(ascii_punctuation)
  defguard is_non_ascii_punct(char) when char in unquote(non_ascii_punctuation)
  defguard is_utf8_punct(char) when char in unquote(punctuation)
  defguard is_ascii_digit(char) when char in unquote(ascii_digits)
  defguard is_non_ascii_digit(char) when char in unquote(non_ascii_digits)
  defguard is_utf8_digit(char) when char in unquote(digits)
end
