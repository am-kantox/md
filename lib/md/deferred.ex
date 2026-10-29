defmodule Md.Deferred do
  @moduledoc """
  Resolution of deferred references.

  A `disclosure` declaration such as `[1]: https://example.com` or
  `[^1]: The note.` registers a label, and the places that *use* the label —
  `[text][1]` (a `pair`) and `[^1]` (a `magnet` with `Md.Transforms.Footnote`)
  — record a placeholder instead of a value, because the declaration may appear
  anywhere in the document.

  This module performs the substitution once the whole document has been
  parsed, and is the only place that knows the placeholder shape.
  """

  @typedoc "A label registered by a `disclosure` declaration"
  @type label :: binary()

  @typedoc "The registry built up during parsing"
  @type registry :: [{label(), binary()}]

  @doc """
  Rewrites `ast`, replacing every deferred placeholder with its resolved value.

  Two placeholder shapes exist:

    * `{:__deferred__, label, [content]}` — a reference whose value *is* the
      declaration's content (`[text][1]`). When the label was never declared,
      the reference degrades to its own content.

    * `{tag, %{__deferred__: meta}, content}` — an element whose attribute is
      deferred (`[^1]`). `meta` may carry a `:fallback`, which wins over the
      registry: a footnote anchors to `#label` rather than to the note's text.

  `Macro.postwalk/2` is used deliberately. Replacing a node with a plain binary
  in a *pre*walk would make the walker revisit the replacement forever, because
  a binary is its own pre-walk result.
  """
  @spec apply(Md.Listener.branch() | [Md.Listener.branch()], registry()) ::
          Md.Listener.branch() | [Md.Listener.branch()]
  def apply(ast, registry) do
    deferreds =
      registry
      |> Enum.filter(&match?({_, _}, &1))
      |> Map.new()

    Macro.postwalk(ast, fn
      {:__deferred__, label, [content]} when is_binary(content) ->
        Map.get(deferreds, label, content)

      {tag, %{__deferred__: meta} = attrs, content} ->
        {tag, attrs |> Map.delete(:__deferred__) |> resolve(meta, deferreds), content}

      other ->
        other
    end)
  end

  @spec resolve(map(), map(), %{optional(label()) => binary()}) :: map()
  defp resolve(attrs, %{attribute: attribute} = meta, deferreds) do
    mark = Map.get(meta, :content)

    value =
      case Map.fetch(meta, :fallback) do
        {:ok, fallback} -> fallback
        :error -> Map.get(deferreds, mark, mark)
      end

    Map.put(attrs, attribute, value)
  end

  @doc """
  Reduces a label as written in a declaration (`[1]`, `[^abc]`) to the bare key
  (`1`, `abc`).

  A `pair` reference (`[a][1]`) and a `magnet` reference (`[^1]`) must resolve
  against the same registry entry, so both sides normalise through this
  function.
  """
  @spec key(binary()) :: binary()
  def key(label) do
    label
    |> String.trim()
    |> String.trim_leading("[")
    |> String.trim_trailing("]")
    |> String.trim_leading("^")
    |> String.trim()
  end
end
