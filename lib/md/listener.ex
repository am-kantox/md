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

  @type parse_mode ::
          :idle
          | :finished
          | :raw
          | :md
          | {:linefeed, non_neg_integer()}
          | {:nested, element(), non_neg_integer()}
          | {:inner, element(), non_neg_integer()}

  @type context ::
          :start
          | :break
          | :linefeed
          | :whitespace
          | :custom
          | {:tag, {binary(), element()}, atom()}
          | {:esc, binary()}
          | {:char, binary()}
          | :finalize
          | :end

  @type state :: %{
          __struct__: Md.Parser.State,
          path: [trace()],
          mode: [parse_mode()],
          ast: [branch()],
          listener: module(),
          bag: %{indent: [non_neg_integer()], stock: [branch()]}
        }

  @callback element(context(), state()) :: :ok | {:update, state()}

  defmacro __using__(opts \\ []) do
    emoji = Keyword.get(opts, :emoji, "📑")

    quote generated: true, location: :keep do
      @behaviour Md.Listener

      require Logger

      def handle_start(state), do: Logger.debug("[#{unquote(emoji)} start]")
      def handle_break(state), do: :ok
      def handle_linefeed(state), do: :ok
      def handle_whitespace(state), do: :ok
      def handle_finalize(state), do: :ok
      def handle_end(state), do: Logger.debug("[#{unquote(emoji)} end]")

      def handle_tag({element, opening?}, state) do
        Logger.debug(
          "[#{unquote(emoji)} tag {#{inspect(element)}, opening: #{opening?}}], Context: " <>
            inspect(state)
        )
      end

      def handle_esc(state), do: :ok
      def handle_char(state), do: :ok

      @impl Md.Listener
      def element({:tag, element, opening?}, state),
        do: handle_tag({element, opening?}, state)

      @impl Md.Listener
      def element(context, state) when is_atom(context),
        do: apply(__MODULE__, :"handle_#{context}", [state])

      @impl Md.Listener
      def element({context, _}, state) when is_atom(context),
        do: element(context, state)

      defoverridable handle_start: 1,
                     handle_break: 1,
                     handle_linefeed: 1,
                     handle_whitespace: 1,
                     handle_finalize: 1,
                     handle_end: 1,
                     handle_tag: 2,
                     handle_esc: 1,
                     handle_char: 1
    end
  end
end

defmodule Md.Listener.Debug do
  @moduledoc false
  use Md.Listener
end
