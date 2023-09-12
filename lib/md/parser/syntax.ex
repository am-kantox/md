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
          optional(:linewrap) => boolean()
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
        ]

  def settings do
    [
      :outer,
      :span,
      :linebreaks,
      :disclosure_range,
      :empty_tags,
      :requiring_attributes_tags,
      :linewrap
    ]
  end

  alias Md.Parser.Syntax.Default

  @spec merge(t()) :: t()
  def merge(custom, default \\ Map.put(Default.syntax(), :settings, Default.settings())) do
    default
    |> Map.merge(custom, fn
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
end
