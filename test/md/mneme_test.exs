defmodule Md.Test.Mneme do
  use ExUnit.Case, async: true
  use Mneme

  test "md parsing" do
    auto_assert(
      "<h2>\n  foo\n</h2>\n<ul>\n  <li>\n    one\n  </li>\n  <li>\n    two\n  </li>\n  <li>\n    three\n  </li>\n</ul>\n<p>\n  test\n</p>" <-
        Md.generate("## foo\n- one\n- two\n- three\n\ntest")
    )
  end
end
