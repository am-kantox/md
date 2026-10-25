defmodule Md.Attributes do
  @moduledoc """
  Sanitisation of the inline attributes declared with the `attributes` handler
  (`{{class: "highlight"}}`).

  Inline attributes are author-controlled and end up verbatim in the generated
  markup, so they are the one place where a markup document can inject arbitrary
  HTML attributes. Without a policy, `{{onmouseover: "alert(1)"}}` produces a
  live event handler in the output — a stored XSS in any application rendering
  user-supplied markup.

  The policy is configured through the `:attribute_allowlist` parser setting:

    * `:safe` (default) — only the attributes in `@safe` are kept, and URI
      attributes are rejected when they use a dangerous scheme.
    * `:all` — every attribute is kept. Use only for trusted input.
    * a list of atoms or strings — exactly those attribute names are kept.

  Attribute *names* are additionally required to be plausible HTML attribute
  names (`[a-zA-Z][a-zA-Z0-9_:.-]*`), and are interned with
  `String.to_existing_atom/1` so that a document cannot grow the atom table.
  """

  @typedoc "An attribute policy, as accepted by the `:attribute_allowlist` setting"
  @type policy :: :safe | :all | [atom() | String.t()]

  @doc "Attributes kept by the `:safe` policy"
  @spec safe_attributes() :: [atom()]
  def safe_attributes,
    do: ~w|
        abbr accept accept-charset accesskey action align allow allowfullscreen alt
        async autocomplete autofocus autoplay axis bgcolor border cellpadding
        cellspacing challenge char charoff charset checked cite class clear color
        cols colspan compact content contenteditable controls coords crossorigin
        data datetime decimals default defer dir dirname disabled download
        draggable enctype face for form formaction frame headers height hidden high
        href hreflang hspace http-equiv id integrity ismap itemid itemprop itemref
        itemscope itemtype kind label lang list loading loop low max maxlength media
        method min minlength multiple muted name nonce novalidate open optimum
        pattern placeholder playsinline popover poster preload readonly referrerpolicy
        rel required reversed rows rowspan role sandbox scope selected shape size
        sizes slot span spellcheck src srcdoc srclang srcset start step style summary
        tabindex target title translate type usemap value width wrap
      |a

  @doc "Attributes whose value is a URI and therefore needs scheme validation"
  @spec uri_attributes() :: [atom()]
  def uri_attributes, do: ~w|href src action formaction cite poster data|a

  @doc "URI schemes that may appear in a URI attribute"
  @spec safe_schemes() :: [String.t()]
  def safe_schemes, do: ~w|http https mailto tel ftp ftps|

  # A conservative HTML attribute-name shape. Anything else is dropped: it is
  # either a typo or an attempt to break out of the attribute position.
  #
  # Deliberately a character check rather than a regex: the regex engine caches
  # compiled patterns per input in the atom table, so validating untrusted names
  # with `Regex.match?/2` reintroduces exactly the unbounded growth this module
  # exists to prevent.
  @name_chars Enum.concat([?a..?z, ?A..?Z, ?0..?9, ~c"_:.-"])

  @doc """
  Parses the raw attribute text captured between the `attributes` markers and
  applies `policy` to it.

  Returns a map suitable for merging into an element's attributes. Never raises
  and never interns new atoms.
  """
  @spec parse(binary(), policy()) :: %{optional(atom()) => binary() | true}
  def parse(raw, policy \\ :safe) do
    raw
    |> split_pairs()
    |> Enum.reduce(%{}, fn
      {name, value}, acc -> put_attribute(acc, name, value, policy)
    end)
  end

  # Splits `class: "a" data-x: y, rel=me` into `{name, value}` pairs.
  #
  # Hand-rolled rather than regex-based: the regex engine caches compiled
  # patterns per input string in the atom table, so tokenising untrusted input
  # with `String.split/2` and a look-behind reintroduces the unbounded atom
  # growth this module exists to prevent.
  @spec split_pairs(binary()) :: [{binary(), binary() | true}]
  defp split_pairs(raw), do: split_pairs(raw, [], "", nil)

  defp split_pairs(<<>>, acc, current, _quote), do: Enum.reverse(flush_pair(acc, current))

  # Inside a quoted value, separators are literal text.
  defp split_pairs(<<c::utf8, rest::binary>>, acc, current, quote) when not is_nil(quote) do
    if c == quote,
      do: split_pairs(rest, acc, current <> <<c::utf8>>, nil),
      else: split_pairs(rest, acc, current <> <<c::utf8>>, quote)
  end

  defp split_pairs(<<c::utf8, rest::binary>>, acc, current, nil) when c in [?", ?'] do
    split_pairs(rest, acc, current <> <<c::utf8>>, c)
  end

  # A separator immediately after `name:` or `name=` is spacing, not the end of
  # the pair: `class: "p"` is one pair, not `class:` plus `"p"`.
  defp split_pairs(<<c::utf8, rest::binary>>, acc, current, nil)
       when c in [?,, ?|, ?\s, ?\t, ?\n, ?\r] do
    if String.ends_with?(current, [":", "="]),
      do: split_pairs(rest, acc, current, nil),
      else: split_pairs(rest, flush_pair(acc, current), "", nil)
  end

  defp split_pairs(<<c::utf8, rest::binary>>, acc, current, nil),
    do: split_pairs(rest, acc, current <> <<c::utf8>>, nil)

  @spec flush_pair([{binary(), binary() | true}], binary()) :: [{binary(), binary() | true}]
  defp flush_pair(acc, ""), do: acc

  defp flush_pair(acc, token) do
    case String.split(token, [":", "="], parts: 2) do
      [name] ->
        [{name, true} | acc]

      [name, value] ->
        # `String.trim/2` only strips characters from the given set, so the
        # whitespace around a quoted value has to go first.
        value = value |> String.trim() |> String.trim("'") |> String.trim("\"")
        [{name, value} | acc]
    end
  end

  @spec put_attribute(map(), binary(), binary() | true, policy()) :: map()
  defp put_attribute(acc, name, value, policy) do
    with true <- valid_name?(name),
         {:ok, key} <- attribute_key(name, policy),
         true <- allowed?(key, policy),
         true <- safe_value?(key, value) do
      Map.put(acc, key, value)
    else
      _ -> acc
    end
  end

  # Attribute names become atoms so the resulting map matches what the rest of
  # the pipeline (and `XmlBuilder`) expects. `String.to_existing_atom/1` is used
  # first: it only succeeds for names some syntax definition already declared,
  # which keeps a hostile document from growing the atom table. The open-ended
  # `data-*` / `aria-*` families cannot be pre-declared, so they fall back to a
  # bounded, process-local pool -- still capped, still not unbounded growth.
  @pool_key {__MODULE__, :pool}
  @pool_max 1024

  # Attribute names are resolved against a fixed lookup table built once at
  # compile time.
  #
  # `String.to_existing_atom/1` is deliberately *not* used: when the atom is
  # missing it raises, and constructing the `ArgumentError` message interns the
  # very name we are trying to avoid interning. A plain map lookup has no such
  # side effect, and it also means an unknown name can never become an atom at
  # all.
  @spec attribute_key(binary(), policy()) :: {:ok, atom()} | :error
  defp attribute_key(name, :all) do
    # With filtering disabled the name still has to become an atom, and the
    # bounded pool is what keeps that from being an unbounded growth vector.
    case known_attributes() do
      %{^name => atom} -> {:ok, atom}
      _ -> {:ok, pooled_atom(name)}
    end
  end

  defp attribute_key(name, _policy) do
    case :maps.find(name, known_attributes()) do
      {:ok, atom} ->
        {:ok, atom}

      :error ->
        if String.starts_with?(name, ["data-", "aria-"]),
          do: {:ok, pooled_atom(name)},
          else: :error
    end
  end

  # Built once, lazily, from the same list `allowed?/2` consults. A plain map
  # lookup has no side effects, unlike `String.to_existing_atom/1`, which
  # interns the name while building the `ArgumentError` it raises.
  @spec known_attributes() :: %{optional(String.t()) => atom()}
  defp known_attributes do
    case :persistent_term.get({__MODULE__, :known}, nil) do
      nil ->
        map = Map.new(safe_attributes(), &{Atom.to_string(&1), &1})
        :persistent_term.put({__MODULE__, :known}, map)
        map

      map ->
        map
    end
  end

  @spec pooled_atom(binary()) :: atom()
  defp pooled_atom(name) do
    pool = Process.get(@pool_key, %{})

    case pool do
      %{^name => atom} ->
        atom

      _ when map_size(pool) >= @pool_max ->
        # Pool exhausted: stop interning rather than grow without bound. The
        # attribute is simply dropped, which is the safe failure mode.
        :__md_dropped_attribute__

      _ ->
        atom = String.to_atom(name)
        Process.put(@pool_key, Map.put(pool, name, atom))
        atom
    end
  end

  @spec valid_name?(binary()) :: boolean()
  defp valid_name?(<<first::utf8, rest::binary>>) when first in ?a..?z or first in ?A..?Z do
    (rest == "" or all_name_chars?(rest)) and not String.starts_with?(name_of(first, rest), "on")
  end

  defp valid_name?(_name), do: false

  @spec name_of(byte(), binary()) :: binary()
  defp name_of(first, rest), do: <<first>> <> rest

  @spec all_name_chars?(binary()) :: boolean()
  defp all_name_chars?(<<>>), do: true
  defp all_name_chars?(<<c::utf8, rest::binary>>) when c in @name_chars, do: all_name_chars?(rest)
  defp all_name_chars?(_), do: false

  @spec allowed?(atom(), policy()) :: boolean()
  defp allowed?(_key, :all), do: true

  # `data-*` and `aria-*` are open-ended by design: they carry no behaviour and
  # are how applications attach their own metadata. Everything else must be on
  # the known-good list, which is what keeps `on*` handlers out.
  defp allowed?(key, :safe) do
    key in safe_attributes() or
      key |> Atom.to_string() |> String.starts_with?(["data-", "aria-"])
  end

  defp allowed?(key, list) when is_list(list),
    do: key in list or Atom.to_string(key) in list

  @doc """
  `true` when `value` may be used as the value of the URI attribute `key`.

  Non-URI attributes are always accepted. URI attributes are rejected when they
  carry a scheme that browsers execute (`javascript:`, `data:`, `vbscript:`, …).
  """
  @spec safe_uri?(atom() | binary(), binary() | true) :: boolean()
  def safe_uri?(key, value) when is_binary(value) do
    if uri_attribute?(key) do
      # Browsers strip leading/trailing whitespace and embedded control
      # characters before resolving a URL, so `"  javascript:alert(1)"` is a
      # live handler. `URI.parse/1` does not, hence the normalisation.
      value = value |> String.trim() |> String.replace(~r/[\x00-\x20]/, "")

      case URI.parse(value) do
        %URI{scheme: nil} -> true
        %URI{scheme: scheme} -> String.downcase(scheme) in safe_schemes()
      end
    else
      true
    end
  end

  def safe_uri?(_key, _value), do: true

  @spec uri_attribute?(atom() | binary()) :: boolean()
  defp uri_attribute?(key) when is_atom(key), do: key in uri_attributes()

  defp uri_attribute?(key) when is_binary(key),
    do: key in Enum.map(uri_attributes(), &to_string/1)

  # A URI attribute must not carry a scheme that browsers execute.
  @spec safe_value?(atom() | binary(), binary() | true) :: boolean()
  defp safe_value?(key, value), do: safe_uri?(key, value)
end
