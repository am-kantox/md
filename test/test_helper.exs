defmodule MyDSLParser do
  defmodule Tag do
    @moduledoc false
    @behaviour Md.Transforms

    @href "/tags/"

    @impl Md.Transforms
    def apply(md, text) do
      href = @href <> URI.encode_www_form(text)
      tag = String.downcase(text)
      {:a, %{class: "tag", "data-tag": tag, href: href}, [md <> text]}
    end
  end

  @my_syntax %{brace: [{"***", %{tag: "u"}}]}

  use Md.Parser, syntax: @my_syntax
  import Md.Parser.DSL

  comment "<!--", %{closing: "-->"}
  magnet "%", %{transform: Tag, terminators: [:ascii_punctuation]}
  linewrap true
end

ExUnit.start()
Mneme.start()
