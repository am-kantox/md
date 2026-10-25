defmodule Md.Parser.Error do
  @moduledoc """
  Diagnostic reporting for an input the generated parser has no clause for.

  `Md.Engine` compiles the syntax map into a `do_parse/2` clause set. Every
  clause is emitted from a syntax declaration, so the set is *closed*: an input
  that reaches the catch-all clause has found a gap in the syntax definition
  (or a bug in the engine), not merely an unusual document.

  This module turns the parser state at that moment into something a maintainer
  can act on. It reports, via `Logger.error/1`:

    * the offending continuation, with its byte size and a `byte_size`-aware
      preview (so a multi-byte character is never split);
    * the full mode stack, top first -- the mode is what selects the clause, so
      it is the single most useful piece of context;
    * the open path (the elements currently being built) and the pending
      `bag` contents;
    * a hint derived from the top mode and the leading bytes, naming the
      construct whose clause is missing.

  It then raises `Md.Parser.Error` with the same information in the message, so
  the failure is visible to the consumer and not only in the log.
  """

  defexception [:message, :continuation, :mode, :path, :bag, :parser, :hint]

  require Logger

  @typedoc "Everything captured at the point the parser got stuck"
  @type t :: %__MODULE__{
          message: String.t(),
          continuation: binary(),
          mode: [Md.Listener.parse_mode()],
          path: [Md.Listener.trace()],
          bag: map(),
          parser: module(),
          hint: String.t() | nil
        }

  # How much of the continuation to show. Enough to recognise the input,
  # short enough to keep the log line readable.
  @preview_bytes 120

  @doc """
  Reports the failure and raises `Md.Parser.Error`.

  Called by the generated catch-all `do_parse/2` clause; not part of the
  public API.
  """
  @spec raise!(binary(), Md.Parser.State.t(), module()) :: no_return()
  def raise!(continuation, state, parser) do
    error = build(continuation, state, parser)

    Logger.error(error.message)

    raise error
  end

  @doc """
  Builds the exception without raising it. Exposed for testing.
  """
  @spec build(term(), Md.Parser.State.t(), module()) :: t()
  def build(continuation, state, parser) do
    mode = Map.get(state, :mode, [])
    path = Map.get(state, :path, [])
    bag = Map.get(state, :bag, %{})

    hint = hint(mode, continuation)

    message =
      [
        "Md: no `do_parse/2` clause matches this input.",
        "",
        "  parser:       #{inspect(parser)}",
        "  continuation: #{preview(continuation)}",
        "  bytes left:   #{bytes_left(continuation)}",
        "  mode:         #{inspect(mode)}",
        "  path:         #{inspect(path, limit: 20)}",
        "  bag:          #{inspect(bag, limit: 20)}",
        "",
        "  hint:         #{hint}",
        "",
        "This is a gap in the syntax definition, not an unusual document: the",
        "clause set is generated from the syntax map, so every reachable input",
        "must be covered by some declaration. The mode above names the construct",
        "whose clause is missing."
      ]
      |> Enum.join("\n")

    %__MODULE__{
      message: message,
      continuation: continuation,
      mode: mode,
      path: path,
      bag: bag,
      parser: parser,
      hint: hint
    }
  end

  @spec bytes_left(term()) :: String.t()
  defp bytes_left(continuation) when is_binary(continuation), do: byte_size(continuation)
  defp bytes_left(_continuation), do: "n/a (not a binary)"

  # A `byte_size`-aware preview: `binary_part/3` never splits a multi-byte
  # character, unlike `String.slice/2` on an arbitrary byte offset.
  #
  # A continuation that is not a binary is itself the bug (a `custom` handler
  # returned the wrong shape), so it is reported as such rather than crashing
  # the reporter -- a diagnostic that raises its own error is worse than none.
  @spec preview(term()) :: String.t()
  defp preview(continuation) when not is_binary(continuation),
    do: "#{inspect(continuation)} (not a binary!)"

  defp preview(continuation) when byte_size(continuation) <= @preview_bytes,
    do: inspect(continuation)

  defp preview(continuation) do
    head = binary_part(continuation, 0, @preview_bytes)
    rest = byte_size(continuation) - @preview_bytes
    "#{inspect(head)} <> #{rest} more bytes"
  end

  @spec hint([Md.Listener.parse_mode()], term()) :: String.t()
  defp hint([], _continuation),
    do: "the mode stack is empty -- `pop_mode/2` popped past the bottom"

  defp hint([mode | _], continuation) do
    case {mode, leading_marker(continuation)} do
      {{:inner, tag, _}, marker} when is_atom(tag) ->
        "mode says a `#{tag}` is being collected; #{marker}"

      {{:nested, tag, _}, marker} when is_atom(tag) ->
        "mode says a nested `#{tag}` paragraph is open; #{marker}"

      {{:comment, opening}, _marker} ->
        "mode says a comment opened with #{inspect(opening)} is still collecting; " <>
          "no clause closes it here"

      {:magnet, marker} ->
        "mode says a `magnet` is collecting a word; #{marker}"

      {:raw, marker} ->
        "mode says a raw segment is open; #{marker}"

      {other, marker} ->
        "mode #{inspect(other)} is open; #{marker}"
    end
  end

  @spec leading_marker(term()) :: String.t()
  defp leading_marker(continuation) when not is_binary(continuation),
    do: "the continuation is not a binary, so no clause can match it"

  defp leading_marker(""), do: "the input is exhausted"

  defp leading_marker(continuation) do
    # Enough to identify the marker without dumping the whole document.
    take = min(byte_size(continuation), 16)
    "the next bytes are #{inspect(binary_part(continuation, 0, take))}"
  end
end
