defmodule Md.Parser.State do
  @moduledoc """
  The internal state of the parser.
  """

  @type t :: Md.Listener.state()
  defstruct path: [],
            ast: [],
            mode: [:idle],
            listener: nil,
            payload: nil,
            bag: %{indent: [], stock: [], deferred: []}

  defimpl Inspect do
    @moduledoc false
    import Inspect.Algebra

    @spec inspect(Md.Listener.state(), Inspect.Opts.t()) ::
            :doc_line
            | :doc_nil
            | binary
            | {:doc_collapse, pos_integer}
            | {:doc_force, any}
            | {:doc_break | :doc_color | :doc_cons | :doc_fits | :doc_group | :doc_string, any,
               any}
            | {:doc_nest, any, :cursor | :reset | non_neg_integer, :always | :break}
    def inspect(
          %Md.Parser.State{
            path: path,
            ast: ast,
            mode: mode,
            payload: payload,
            bag: %{indent: indent, stock: stock, deferred: deferred}
          },
          opts
        ) do
      inner = [
        path: path,
        ast: ast,
        payload: payload,
        internals: [mode: mode, indent: indent, stock: stock, deferred: deferred]
      ]

      concat(["#Md<", to_doc(inner, opts), ">"])
    end
  end
end
