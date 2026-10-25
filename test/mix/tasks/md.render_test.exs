defmodule Mix.Tasks.Md.RenderTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @moduletag :tmp_dir

  defp render(argv) do
    capture_io(fn -> Mix.Tasks.Md.Render.run(argv) end)
  end

  test "renders a file to standard output", %{tmp_dir: dir} do
    path = Path.join(dir, "in.md")
    File.write!(path, "*hi* there")

    assert render([path]) == "<p><b>hi</b> there</p>\n"
  end

  test "writes to a file with --output", %{tmp_dir: dir} do
    input = Path.join(dir, "in.md")
    output = Path.join(dir, "out.html")
    File.write!(input, "# Title")

    render([input, "--output", output])

    assert File.read!(output) == "<h1>Title</h1>"
  end

  test "accepts --format indent", %{tmp_dir: dir} do
    path = Path.join(dir, "in.md")
    File.write!(path, "*hi*")

    assert render([path, "--format", "indent"]) =~ "\n"
  end

  test "rejects an unknown --format", %{tmp_dir: dir} do
    path = Path.join(dir, "in.md")
    File.write!(path, "x")

    assert_raise Mix.Error, ~r/unknown --format/, fn -> render([path, "--format", "nope"]) end
  end

  test "rejects more than one input file" do
    assert_raise Mix.Error, ~r/at most one input file/, fn -> render(["a.md", "b.md"]) end
  end

  test "reads standard input when no file is given" do
    assert capture_io("*hi*", fn -> Mix.Tasks.Md.Render.run([]) end) ==
             "<p><b>hi</b></p>\n"
  end
end
