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

  if Application.compile_env(:md, :use_string_naming, false) and Code.ensure_loaded?(StringNaming) do
    [digits, punctuation, spaces] =
      [~r/digit/i, ~r/punct/i, ~r/space/i]
      |> Enum.map(fn re ->
        StringNaming
        # credo:disable-for-next-line Credo.Check.Refactor.Apply
        |> apply(:graphemes, [re, false])
        |> Enum.map_join(&elem(&1, 1))
        |> to_charlist()
      end)

    punctuation = punctuation -- ~c"_"
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
  else
    require Unicode.Guards
    require Unicode.Set

    import Unicode.Guards
    import Unicode.Set, only: [match?: 2]
    import Kernel, except: [match?: 2]

    defguard is_ascii_space(char) when is_whitespace(char) and char < 128
    defguard is_non_ascii_space(char) when is_whitespace(char) and char >= 128
    defguard is_utf8_space(char) when is_whitespace(char)
    defguard is_ascii_punct(char) when is_integer(char) and match?(char, "[[:P:]]") and char < 128

    defguard is_non_ascii_punct(char)
             when is_integer(char) and match?(char, "[[:P:]]") and char >= 128

    defguard is_utf8_punct(char) when is_integer(char) and match?(char, "[[:P:]]")
    defguard is_ascii_digit(char) when is_integer(char) and match?(char, "[[:N:]]") and char < 128

    defguard is_non_ascii_digit(char)
             when is_integer(char) and match?(char, "[[:N:]]") and char >= 128

    defguard is_utf8_digit(char) when is_integer(char) and match?(char, "[[:N:]]")
  end

  @doc false
  defguard in_short_list(what, list)
           when hd(list) == what or
                  hd(tl(list)) == what or
                  hd(tl(tl(list))) == what or
                  hd(tl(tl(tl(list)))) == what or
                  hd(tl(tl(tl(tl(list))))) == what or
                  hd(tl(tl(tl(tl(tl(list)))))) == what or
                  hd(tl(tl(tl(tl(tl(tl(list))))))) == what or
                  hd(tl(tl(tl(tl(tl(tl(tl(list)))))))) == what or
                  hd(tl(tl(tl(tl(tl(tl(tl(tl(list))))))))) == what or
                  hd(tl(tl(tl(tl(tl(tl(tl(tl(tl(list)))))))))) == what

  @doc false
  # A disclosure label is a single bracketed token on a single line: `[1]`,
  # `[^abc]`. A token such as `[a][1]` is a *reference*, not a declaration.
  #
  # This is a plain function, not a guard, on purpose. Guards cannot
  # short-circuit `and`, `binary_part/3` raises when reading past the end of a
  # binary, and `String` functions are not guard-legal at all -- expressing this
  # as a guard requires either generated per-length clauses or a scan that
  # raises on short labels. A function called from the clause *body* is both
  # simpler and obviously correct; the engine handles a `false` result by
  # falling through to the `pair` handler.
  @spec disclosure_label?(binary()) :: boolean()
  def disclosure_label?(label) when is_binary(label) and byte_size(label) > 2 do
    inner = binary_part(label, 1, byte_size(label) - 2)

    binary_part(label, 0, 1) == "[" and
      binary_part(label, byte_size(label) - 1, 1) == "]" and
      not String.contains?(inner, ["\n", "\r", "[", "]"])
  end

  def disclosure_label?(_label), do: false
end
