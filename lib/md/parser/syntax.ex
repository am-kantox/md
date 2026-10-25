defmodule Md.Parser.Syntax do
  @moduledoc """
  The behaviour for the custom syntax suppliers
  """

  @typedoc "Settings for the parser"
  @type settings :: %{
          optional(:outer) => atom(),
          optional(:span) => atom(),
          optional(:linebreaks) => [binary()],
          optional(:disclosure_range) => Range.t(),
          optional(:empty_tags) => [atom()],
          optional(:requiring_attributes_tags) => [atom()],
          optional(:linewrap) => boolean(),
          optional(:attribute_allowlist) => Md.Attributes.policy()
        }

  @typedoc "Syntax item definition"
  @type item :: {binary(), map()}

  @typedoc "Syntax definition"
  @type t :: %{
          custom: [item()],
          attributes: [item()],
          substitute: [item()],
          escape: [item()],
          comment: [item()],
          matrix: [item()],
          flush: [item()],
          magnet: [item()],
          block: [item()],
          shift: [item()],
          pair: [item()],
          disclosure: [item()],
          paragraph: [item()],
          list: [item()],
          tag: [item()],
          brace: [item()]
        }

  @doc "The implementation should return settings for this particular syntax definition"
  @callback settings :: settings()

  @doc "The implementation should return a syntax definition"
  @callback syntax :: t()

  @doc false
  @spec types :: [
          :custom
          | :attributes
          | :substitute
          | :escape
          | :comment
          | :matrix
          | :flush
          | :magnet
          | :block
          | :shift
          | :pair
          | :disclosure
          | :paragraph
          | :list
          | :tag
          | :brace
        ]
  def types do
    [
      :custom,
      :attributes,
      :substitute,
      :escape,
      :comment,
      :matrix,
      :flush,
      :magnet,
      :block,
      :shift,
      :pair,
      :disclosure,
      :paragraph,
      :list,
      :tag,
      :brace
    ]
  end

  @doc false
  @spec settings :: [
          :outer
          | :span
          | :linebreaks
          | :disclosure_range
          | :empty_tags
          | :requiring_attributes_tags
          | :linewrap
          | :attribute_allowlist
        ]

  def settings do
    [
      :outer,
      :span,
      :linebreaks,
      :disclosure_range,
      :empty_tags,
      :requiring_attributes_tags,
      :linewrap,
      :attribute_allowlist
    ]
  end

  alias Md.Parser.Syntax.Default

  @doc """
  Merges a custom syntax definition into `default`.

  Categories other than `:settings` are merged item-wise and then sorted by
  **descending marker length**, so a longer marker is always tried before a
  shorter one that prefixes it (`"**"` before `"*"`, `"!!["` before `"!["`).

  `:settings` is a plain `atom => term` map rather than a list of
  `{marker, properties}` items, so it is merged as a map and left as one.

  When `default` is omitted, `Md.Parser.Syntax.Default` is used. That default
  is resolved lazily: `Default` builds itself by calling `merge/2`, so reading
  it in the *head* of this function would be a compile-time cycle.
  """
  @spec merge(t()) :: t()
  def merge(custom), do: merge(custom, default_syntax())

  @doc false
  @spec merge(t(), t()) :: t()
  def merge(custom, default) do
    default
    |> Map.merge(custom, fn
      # `:settings` is a plain `atom => term` map (see `t:settings/0`), not a
      # list of `{prefix_string, properties}` items like every other syntax
      # category -- it must stay a map through the merge, or the sort-by-prefix
      # step below (which assumes a `String.length/1`-able key) crashes on it.
      :settings, v1, v2 ->
        [v2, v1] |> Enum.map(&Map.new/1) |> Enum.reduce(&Map.merge/2)

      _k, v1, v2 ->
        [v2, v1] |> Enum.map(&Map.new/1) |> Enum.reduce(&Map.merge/2) |> Map.to_list()
    end)
    |> Enum.map(fn
      {k, v} when is_list(v) ->
        {k, Enum.sort_by(v, &(-String.length(elem(&1, 0))))}

      {k, v} ->
        {k, v}
    end)
    |> Map.new()
  end

  @spec default_syntax() :: t()
  defp default_syntax, do: Map.put(Default.syntax(), :settings, Default.settings())
end
