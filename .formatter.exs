locals_without_parens = [
  # DSL
  custom: 2,
  substitute: 2,
  escape: 2,
  comment: 2,
  matrix: 2,
  flush: 2,
  magnet: 2,
  block: 2,
  shift: 2,
  pair: 2,
  disclosure: 2,
  paragraph: 2,
  list: 2,
  brace: 2
]

[
  locals_without_parens: locals_without_parens,
  import_deps: if(Mix.env() == :test, do: [:mneme], else: []),
  export: [
    locals_without_parens: locals_without_parens
  ],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
