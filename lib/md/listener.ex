defmodule Md.Listener do
  @moduledoc """
  The listener behaviour to attach to the parser to receive callbacks
  when the elements are encountered and processed.
  """

  @type element :: atom()
  @type attributes :: nil | %{required(element()) => any()}
  @type leaf :: binary()
  @type branch :: {element(), attributes(), [leaf() | branch()]}
  @type trace :: branch()

  @type context ::
          :break
          | :linefeed
          | {:nested, element(), non_neg_integer()}
          | :whitespace
          | :end
          | {:tag, binary(), nil | true | false}
          | {:esc, binary()}
          | {:char, binary()}

  @type state :: %{
          __struct__: Md.Parser.State,
          path: [trace()],
          ast: [branch()],
          listener: module(),
          bag: list()
        }

  @callback element(context(), state()) :: :ok | {:update, state()}
end
