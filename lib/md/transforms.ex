defmodule Md.Transforms do
  @moduledoc false
  alias Md.Listener, as: L
  @callback apply(binary(), binary()) :: L.branch()
end

defmodule Md.Transforms.Anchor do
  @moduledoc false
  @behaviour Md.Transforms

  """
  <meta name="twitter:image:src"
    content="https://repository-images.githubusercontent.com/409629199/84001e50-746c-4603-a9c2-b731d7e4c94e" />
  <meta name="twitter:site" content="@github" />
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="GitHub - am-kantox/md: Stream-aware markdown parser with custom syntax setting" />
  <meta name="twitter:description" content="Stream-aware markdown parser with custom syntax setting - GitHub - am-kantox/md: Stream-aware markdown parser with custom syntax setting" />

  <meta property="og:image"
    content="https://repository-images.githubusercontent.com/409629199/84001e50-746c-4603-a9c2-b731d7e4c94e" />
  <meta property="og:image:alt" content="Stream-aware markdown parser with custom syntax setting - GitHub - am-kantox/md: Stream-aware markdown parser with custom syntax setting" />
  <meta property="og:site_name" content="GitHub" />
  <meta property="og:type" content="object" />
  <meta property="og:title" content="GitHub - am-kantox/md: Stream-aware markdown parser with custom syntax setting" />
  <meta property="og:url" content="https://github.com/am-kantox/md" />
  <meta property="og:description" content="Stream-aware markdown parser with custom syntax setting - GitHub - am-kantox/md: Stream-aware markdown parser with custom syntax setting" />
  """

  @impl Md.Transforms
  def apply(_md, url) do
    text =
      with {:ok, {{_proto, 200, _ok}, _headers, html}} <- :httpc.request(url),
           {:ok, document} <- Floki.parse_document(html),
           metas <- Floki.find(document, "meta") do
        props =
          for({"meta", props, []} <- metas, do: props)
          |> Enum.map(&Map.new/1)
          |> Enum.reduce(%{}, fn
            %{"name" => "twitter:" <> tw, "content" => content}, acc ->
              Map.put(acc, "twitter:" <> tw, content)

            %{"property" => "og:" <> og, "content" => content}, acc ->
              Map.put(acc, "og:" <> og, content)

            _, acc ->
              acc
          end)
      end

    ast =
      case text do
        {:ok, text} when is_binary(text) -> [text]
        {:ok, ast} when is_list(ast) -> ast
        _ -> [url]
      end

    {:a, %{href: url}, ast}
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
