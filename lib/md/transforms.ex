defmodule Md.Transforms do
  @moduledoc false
  alias Md.Listener, as: L
  @callback apply(binary(), binary()) :: L.branch()
end

defmodule Md.Transforms.Anchor do
  @moduledoc false
  @behaviour Md.Transforms

  @impl Md.Transforms
  def apply(_md, text) do
    {:a, %{href: text}, [text]}
  end
end

defmodule Md.Transforms.Footnote do
  @moduledoc false
  @behaviour Md.Transforms

  @impl Md.Transforms
  def apply(md, text) do
    # TODO closing is needed here
    ref = String.slice(text, String.length(md)..-2)

    {:a, %{__deferred__: %{attribute: :href, content: text, kind: :attribute}},
     [{:sup, nil, [ref]}]}
  end
end

defmodule Md.Transforms.TwitterHandle do
  @moduledoc false
  @behaviour Md.Transforms

  @href "https://twitter.com/"

  @impl Md.Transforms
  def apply(md, text) do
    {:a, %{href: @href <> text}, [md <> text]}
  end
end
