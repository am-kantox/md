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

defmodule Md.Transforms.TwitterHandle do
  @moduledoc false
  @behaviour Md.Transforms

  @href "https://twitter.com/"

  @impl Md.Transforms
  def apply(md, text) do
    {:a, %{href: @href <> text}, [md <> text]}
  end
end
