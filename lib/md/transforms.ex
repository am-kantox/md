defmodule Md.Transforms do
  @moduledoc false
  alias Md.Listener, as: L
  @callback apply(binary(), binary()) :: L.branch()
end

defmodule Md.Transforms.Anchor do
  @moduledoc false
  @behaviour Md.Transforms

  @spec dig(map(), binary()) :: nil | binary()
  defp dig(data, key) do
    get_in(data, ["html", key]) || get_in(data, ["twitter", key]) || get_in(data, ["og", key])
  end

  @spec dig_image_size(map()) :: nil | {non_neg_integer(), non_neg_integer()}
  defp dig_image_size(data) do
    case data do
      %{"og" => %{"image:width" => w, "image:height" => h}} -> {w, h}
      %{"twitter" => %{"card" => "summary_large_image"}} -> {640, 480}
      _ -> {480, 360}
    end
  end

  @impl Md.Transforms
  def apply(_md, url) do
    what_to_apply =
      if Path.extname(url) in ~w|.png .jpg .jpeg .gif|,
        do: :image,
        else: Application.get_env(:md, :download_cards, false)

    do_apply(url, what_to_apply)
  end

  @spec do_apply(binary(), true | false | :image) :: Md.Listener.branch()
  defp do_apply(url, :image), do: {:img, %{src: url}, []}
  defp do_apply(url, false), do: {:a, %{href: url}, [url]}

  case Code.ensure_compiled(Floki) do
    {:module, Floki} ->
      defp do_apply(url, true) do
        ast =
          with {:ok, {{_proto, 200, _ok}, _headers, html}} <- :httpc.request(url),
               {:ok, document} <- Floki.parse_document(html),
               metas <- Floki.find(document, "meta") do
            data =
              for({"meta", props, []} <- metas, do: props)
              |> Enum.map(&Map.new/1)
              |> Enum.reduce(%{}, fn
                %{"name" => "title", "content" => content}, acc ->
                  put_in(acc, [Access.key("html", %{}), "title"], utf8(content))

                %{"name" => "description", "content" => content}, acc ->
                  put_in(acc, [Access.key("html", %{}), "description"], utf8(content))

                %{"name" => "keywords", "content" => content}, acc ->
                  put_in(acc, [Access.key("html", %{}), "keywords"], utf8(content))

                %{"name" => "twitter:" <> tw, "content" => content}, acc ->
                  put_in(acc, [Access.key("twitter", %{}), tw], utf8(content))

                %{"property" => "og:" <> og, "content" => content}, acc ->
                  put_in(acc, [Access.key("og", %{}), og], utf8(content))

                _, acc ->
                  acc
              end)

            data = %{
              title: dig(data, "title"),
              description: dig(data, "description"),
              image: get_in(data, ["twitter", "image:src"]) || get_in(data, ["og", "image"]),
              alt: get_in(data, ["og", "image:alt"]),
              size: dig_image_size(data),
              url: dig(data, "url")
            }

            case {data.image, data.description, data.title} do
              {nil, nil, nil} ->
                [url]

              {nil, nil, title} ->
                [title]

              {nil, description, nil} ->
                [description]

              _ ->
                [
                  {:figure, %{class: "card"},
                   [
                     {:img, %{src: data.image, alt: data.alt}, []},
                     {:figcaption, %{},
                      [
                        {:b, %{class: "card-title"}, [data.title]},
                        {:br, %{}, []},
                        {:span, %{class: "card-description"}, [data.description]}
                      ]}
                   ]}
                ]
            end
          end

        {:a, %{href: url}, if(is_list(ast), do: ast, else: [url])}
      end

      defp utf8(content) do
        content
        |> String.to_charlist()
        |> IO.iodata_to_binary()
      rescue
        ArgumentError ->
          content
          |> String.to_charlist()
          |> IO.chardata_to_string()
      end

    _ ->
      Mix.shell().info([
        [:bright, :yellow, "[INFO] ", :reset],
        "You’ve chosen `Md.Transforms.Anchor` to be used. ",
        "Add `:floki` dependency for it to build the twitter/og cards up!"
      ])

      defp do_apply(url, true), do: {:a, %{href: url}, [url]}
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
    {:a, %{href: @href <> URI.encode_www_form(text)}, [md <> text]}
  end
end
