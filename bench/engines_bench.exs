Benchfella.start()

defmodule Md.Bench do
  use Benchfella

  # `priv/earmark.md` is a plain markdown fixture, kept under its historical
  # name. The benchmark deliberately does *not* pull in a third-party parser:
  # the previous `earmark` comparison dragged in a deprecated dependency with
  # an open security advisory, and a native-parser baseline (`mdex`) would make
  # `:ci` depend on precompiled Rust NIFs for a number that is not part of the
  # test suite. Track `Md` against itself instead.
  @input File.read!("priv/earmark.md")

  bench "md (full document)" do
    Md.generate(@input)
  end

  bench "md (parse only)" do
    Md.parse(@input)
  end
end
