[
  # ---------------------------------------------------------------------------
  # Dialyzer cannot analyse the macro-generated parser.
  #
  # `do_parse/2` is emitted as hundreds of clauses by `Md.Engine`'s macros, one
  # per syntax declaration. Dialyzer cannot prove that the resulting clause set
  # terminates, so it infers `no_return()` and flags the (correct) `@spec` as an
  # invalid contract. The parser is exercised by the whole test suite, including
  # property tests over generated input.
  #
  # The format is `{file, warning_type}`, which suppresses every warning of that
  # type in that file. Anything not listed here is a real problem and must be
  # fixed rather than silenced.
  # ---------------------------------------------------------------------------

  # `generate/2` dispatches on the second argument's shape (options list vs
  # parser module); Dialyzer cannot narrow it when the list came from
  # `Keyword.put/3` in a caller.
  {"lib/md/parser.ex", :call},

  # `Syntax.merge/2` folds a heterogeneous list of `{marker, properties}` items
  # with `Enum.reduce/3`. Dialyzer infers the union of the *narrowest* binary
  # types it saw (e.g. `<<_::16>>` for a two-byte marker) instead of widening to
  # `binary()`, then reports that the result "breaks the contract"
  # `(t(), t()) :: t()` -- even though a narrower binary is a subtype of the
  # declared one. Covered by `test/md/syntax_test.exs` and by every parser the
  # suite builds.
  {"lib/md/parser/syntax.ex", :invalid_contract},
  {"lib/md/parser/syntax.ex", :call},
  {"lib/md/parser/syntax.ex", :no_return},

  # Every warning inside `Md.Parser.Default` is attributed to the module rather
  # than to the macro that emitted the clause, because the module is built by
  # `use Md.Parser`. These two are the `apply_deferreds/1` and `do_parse/2`
  # cases already explained above.
  {"lib/md/parser/default.ex", :invalid_contract},

  # `Mix.Task`'s `run/1` returns whatever `Mix.shell().info/1` returned, so its
  # success typing is `:ok | String.t()`; `Mix.raise/1` makes `render/2` and
  # `read_input/1` `no_return` on their error branches. The task is covered by
  # `test/mix/tasks/md.render_test.exs`, including both error branches.
  {"lib/mix/tasks/md.render.ex", :invalid_contract},
  {"lib/mix/tasks/md.render.ex", :no_return},
  {"lib/mix/tasks/md.render.ex", :call}
]
