locals_without_parens = [
  # DSL handlers
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
  brace: 2,
  # DSL settings
  outer: 1,
  span: 1,
  linebreaks: 1,
  disclosure_range: 1,
  empty_tags: 1,
  requiring_attributes_tags: 1,
  linewrap: 1,
  attribute_allowlist: 1
]

[
  locals_without_parens: locals_without_parens,
  export: [
    locals_without_parens: locals_without_parens
  ],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
