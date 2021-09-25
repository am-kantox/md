defmodule Md.Listener do
  @moduledoc """
  The listener behaviour to attach to the parser to receive callbacks
  when the elements are encountered and processed.
  """

  @type context ::
          :break
          | :linefeed
          | :whitespace
          | :end
          | {:tag, binary(), nil | true | false}
          | {:esc, binary()}
          | {:char, binary()}

  @type element :: atom()
  @type attributes :: nil | %{required(element()) => any()}
  @type leaf :: binary()
  @type branch :: {element(), attributes(), [leaf() | branch()]}
  @type trace :: branch()

  @type state :: %{
          __struct__: Md.Parser.State,
          path: [trace()],
          ast: [branch()],
          listener: module(),
          bag: list()
        }

  @callback element(context(), state()) :: :ok | {:update, state()}
end
