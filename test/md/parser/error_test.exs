defmodule Md.Parser.ErrorTest do
  @moduledoc """
  Tests for the diagnostic raised by the generated catch-all `do_parse/2`
  clause.

  The clause set is generated from the syntax map, so reaching the catch-all
  means the syntax definition does not cover the input. These tests pin that
  the report is *useful*: it must name the parser, the mode, the continuation
  and the open path, and it must never fail while reporting.
  """
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Md.Parser.Error
  alias Md.Parser.State

  # A `custom` handler that returns a continuation no clause can match. This is
  # the realistic way to reach the catch-all: a third-party handler returning
  # the wrong shape.
  defmodule BadHandler do
    @moduledoc false
    def parse(_rest, _state), do: {:not_a_binary, %Md.Parser.State{}}
  end

  defmodule BadParser do
    @moduledoc false
    use Md.Parser

    @syntax Md.Parser.Syntax.merge(%{custom: [{"!!", {BadHandler, %{}}}]})
  end

  defp trigger(input \\ "!!boom") do
    Md.parse(input, %State{type: BadParser})
  end

  describe "the catch-all clause" do
    test "raises Md.Parser.Error rather than a bare FunctionClauseError" do
      assert_raise Error, fn -> trigger() end
    end

    test "logs the failure at :error level before raising" do
      log =
        capture_log(fn ->
          assert_raise Error, fn -> trigger() end
        end)

      assert log =~ "[error]"
      assert log =~ "no `do_parse/2` clause matches this input"
    end

    test "the log and the exception carry the same message" do
      log =
        capture_log(fn ->
          assert_raise Error, fn -> trigger() end
        end)

      error =
        try do
          trigger()
        rescue
          e in Error -> e
        end

      assert log =~ error.message
    end
  end

  describe "the report" do
    setup do
      error =
        try do
          trigger()
        rescue
          e in Error -> e
        end

      %{error: error}
    end

    test "names the parser that got stuck", %{error: error} do
      assert error.parser == BadParser
      assert error.message =~ "BadParser"
    end

    test "reports the offending continuation", %{error: error} do
      assert error.continuation == :not_a_binary
      assert error.message =~ "not a binary"
    end

    test "reports the mode stack", %{error: error} do
      assert is_list(error.mode)
      assert error.message =~ "mode:"
    end

    test "reports the open path and the bag", %{error: error} do
      assert is_list(error.path)
      assert is_map(error.bag)
      assert error.message =~ "path:"
      assert error.message =~ "bag:"
    end

    test "carries a hint that points at the cause", %{error: error} do
      assert is_binary(error.hint)
      assert error.message =~ "hint:"
    end

    test "explains that this is a syntax gap, not an odd document", %{error: error} do
      assert error.message =~ "gap in the syntax definition"
    end
  end

  describe "build/3" do
    test "does not raise, so it can be inspected" do
      error = Error.build("rest", %State{mode: [:md]}, __MODULE__)

      assert %Error{} = error
      assert error.continuation == "rest"
      assert error.mode == [:md]
    end

    test "truncates a long continuation without splitting a multi-byte character" do
      # 200 copies of a 3-byte character: a naive `String.slice/2` on a byte
      # offset would produce invalid UTF-8 here.
      continuation = String.duplicate("日", 200)
      error = Error.build(continuation, %State{mode: [:md]}, __MODULE__)

      assert error.message =~ "more bytes"
      # The message must be valid UTF-8.
      assert String.valid?(error.message)
    end

    test "survives a continuation that is not a binary" do
      error = Error.build(:nope, %State{mode: [:md]}, __MODULE__)

      assert error.message =~ "not a binary"
      assert error.message =~ "n/a (not a binary)"
    end

    test "survives an empty mode stack" do
      error = Error.build("rest", %State{mode: []}, __MODULE__)

      assert error.message =~ "mode stack is empty"
    end

    test "hints at the construct named by the mode" do
      for {mode, expected} <- [
            {{:inner, :li, 0}, "`li`"},
            {{:nested, :h2, 1}, "`h2`"},
            {{:comment, "<!--"}, "comment"},
            {:magnet, "magnet"},
            {:raw, "raw"}
          ] do
        error = Error.build("rest", %State{mode: [mode]}, __MODULE__)
        assert error.message =~ expected, "expected #{inspect(mode)} to mention #{expected}"
      end
    end

    test "shows the leading bytes of the continuation" do
      error = Error.build("**bold**", %State{mode: [:md]}, __MODULE__)

      assert error.message =~ "**bold**"
    end

    test "reports an exhausted input distinctly" do
      error = Error.build("", %State{mode: [:md]}, __MODULE__)

      assert error.message =~ "input is exhausted"
    end
  end

  describe "the parser is otherwise total" do
    test "ordinary input never reaches the catch-all" do
      # The catch-all must stay unreachable for well-formed documents, or it
      # would turn a working parse into an exception.
      for input <- [
            "",
            "   ",
            "*bold*",
            "[a](b)",
            "![alt](x.png)",
            "[a][1]\n\n[1]: https://e.com",
            "x[^1]",
            "# Heading",
            "- a\n- b",
            "> quote",
            "```\nelixir\n```",
            "| a | b |\n|---|---|\n| 1 | 2 |",
            "text{{class: \"x\"}}",
            "<sup>2</sup>",
            "<!-- comment -->"
          ] do
        assert %State{} = Md.parse(input)
      end
    end
  end
end
