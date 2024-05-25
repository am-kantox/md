import Config

config :md, syntax: %{
  brace: [
    {"==", %{tag: :b, attributes: %{color: :red}}}
  ]
}
