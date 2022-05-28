defmodule Md.Parser.Syntax do
  @moduledoc """
  The behaviour for the custom syntax suppliers
  """

  @typedoc "Settings for the parser"
  @type settings :: %{
          optional(:outer) => atom(),
          optional(:span) => atom(),
          optional(:linebreaks) => [nonempty_binary()],
          optional(:disclosure_range) => Range.t(),
          optional(:empty_tags) => [atom()]
        }

  @typedoc "Syntax item definition"
  @type item :: {binary(), map()}

  @typedoc "Syntax definition"
  @type t :: %{
          custom: [item()],
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

  @doc "List of different types of markup"
  @spec types :: [
          :custom
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
end
