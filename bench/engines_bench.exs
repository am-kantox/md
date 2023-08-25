Benchfella.start()

defmodule Md.Bench do
  use Benchfella

  @input File.read!("priv/earmark.md")

  bench "earmark" do
    Earmark.as_html!(@input)
  end

  bench "md" do
    Md.generate(@input)
  end
end
