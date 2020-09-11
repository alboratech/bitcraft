defmodule Bitcraft.BitBlock do
  @moduledoc ~S"""
  Defines a bit-block.

  A bit-block is used to map a bitstring into an Elixir struct.
  The definition of the bit-block is possible through `defblock/3`.

  `defblock/3` is typically used to decode bitstring from a bit stream,
  usually a binary protocol (e.g.: TCP/IP), into Elixir structs and
  vice-versa (encoding Elixir structs into a bitstring).

  ## Example

      defmodule MyBlock do
        import Bitcraft.BitBlock

        defblock "my-static-block" do
          segment(:h, 5, type: :binary)
          segment(:s1, 4, default: 1)
          segment(:s2, 8, default: 1, sign: :signed)
          segment(:t, 3, type: :binary)
        end
      end

  The `segment` macro defines a segment in the bit-block with given
  name and size. Bit-blocks are regular structs and can be created
  and manipulated directly using Elixir's struct API:

      iex> block = %MyBlock{h: "begin", s1: 3, s2: -3, t: "end"}
      iex> %{block | h: "hello"}

  By default, a bit-block will automatically generate the implementation
  for the callbacks `c:encode/1` and `c:decode/3`. You can then encode
  the struct into a bitstring and then decode a bitstring into a Elixir
  struct, like so:

      iex> bits = MyBlock.encode(block)
      iex> data = MyBlock.decode(bits)

  What we defined previously it is a static block, means a fixed size always.
  This is the easiest scenario because we don't need to provide any additional
  logic to the the `encode/1` and `decode/3` functions. For that reason,
  in the example above, we call `decode` function only with the input
  bitstring, the other arguments are not needed since they are ment to
  resolve the size for dynamic segments.

  ## Dynamic Segments

  There are other scenarios where the block of bits is dynamic, means
  the size of the block is variable and depends on other segment values
  to calculate the size, this makes it more complicated to decode it.
  For those variable blocks, we can define dynamic segments using the
  `segment/3` API:

      segment(:var, :dynamic, type: :bits)

  As you can see, for the size argument we are passing `:dynamic` atom.
  In this way, the segment is marked as dynamic and its size is resolved
  later during the decoding process.

  The following is a more elaborate example of block. We define an IPv4
  datagram which has a static and a dynamic part. The dynamic part is
  basically the options and the data. The block can be defined as:

      defmodule IpDatagram do
        @moduledoc false
        import Bitcraft.BitBlock

        defblock "IP-datagram" do
          segment(:vsn, 4)
          segment(:hlen, 4)
          segment(:srvc_type, 8)
          segment(:tot_len, 16)
          segment(:id, 16)
          segment(:flags, 3)
          segment(:frag_off, 13)
          segment(:ttl, 8)
          segment(:proto, 8)
          segment(:hdr_chksum, 16, type: :bits)
          segment(:src_ip, 32, type: :bits)
          segment(:dst_ip, 32, type: :bits)
          segment(:opts, :dynamic, type: :bits)
          segment(:data, :dynamic, type: :bits)
        end

        # Size resolver for dynamic segments invoked during the decoding
        def calc_size(%__MODULE__{hlen: hlen}, :opts, dgram_s)
            when hlen >= 5 and 4 * hlen <= dgram_s do
          opts_s = 4 * (hlen - 5)
          {opts_s * 8, dgram_s}
        end

        def calc_size(%__MODULE__{leftover: leftover}, :data, dgram_s) do
          data_s = :erlang.bit_size(leftover)
          {data_s, dgram_s}
        end
      end

  Here, the segment corresponding to the `:opts` segment has a type modifier,
  specifying that `:opts` is to bind to a bitstring (or binary). All other
  segments have the default type equal to unsigned integer.

  An IP datagram header is of variable length. This length is measured in the
  number of 32-bit words and is given in the segment corresponding to `:hlen`.
  The minimum value of `:hlen` is 5. It is the segment corresponding to
  `:opts` that is variable, so if `:hlen` is equal to 5, `:opts` becomes
  an empty binary. Finally, the tail segment `:data` bind to bitstring.

  The decoding of the datagram fails if one of the following occurs:

    * The first 4-bits segment of datagram is not equal to 4.
    * `:hlen` is less than 5.
    * The size of the datagram is less than `4*hlen`.

  Since this block has dynamic segments, we can now use the other decode
  arguments to resolve the size for them during the decoding process:

      IpDatagram.decode(bits, :erlang.bit_size(bits), &IpDatagram.calc_size/3)

  Where:

    * The first argument is the input IPv4 datagram (bitstring).
    * The second argument is is the accumulator to the callback function
      (third argument), in this case is the total number of bits in the
      datagram.
    * And the third argument is the function callback or dynamic size resolver
      that will be invoked by the decoder for each dynamic segment. The callback
      functions receives the data struct with the current decoded segments, the
      segment name (to be pattern-matched and resolve its size), and the
      accumulator that can be used to pass metadata during the dynamic
      segments evaluation.

  ## Reflection

  Any bit-block module will generate the `__bit_block__` function that can be
  used for runtime introspection of the bit-block:

    * `__bit_block__(:name)` - Returns the name or alias as given to
      `defblock/3`.
    * `__bit_block__(:segments)` - Returns a list of all segments names.
    * `__schema__(:segment_info, segment)` - Returns a map with the segment
      info.

  ## Working with typespecs

  By default, the typespec `t/0` is generated but in the simplest form:

      @type t :: %__MODULE__{}

  If you want to provide a more accurate typespec for you block adding the
  typespecs for each of the segments on it, you can set the option `:typespec`
  to `false` when defining the block, like so:

      defblock "my-block", typespec: false do
        ...
      end
  """

  import Record

  # Block segment record
  defrecord(:block_segment,
    name: nil,
    size: nil,
    type: nil,
    sign: nil,
    endian: nil,
    default: nil
  )

  @typedoc "Block's segment definition"
  @type block_segment ::
          record(:block_segment,
            name: atom,
            size: integer | :dynamic | nil,
            type: atom,
            sign: atom,
            endian: atom,
            default: term
          )

  @typedoc "Segment types"
  @type seg_type ::
          :integer
          | :float
          | :bitstring
          | :bits
          | :binary
          | :bytes
          | :utf8
          | :utf16
          | :utf32

  @typedoc "Resolver function for the size of dynamic segments."
  @type dynamic_size_resolver ::
          (struct :: map, seg_name :: atom, acc :: term ->
             {size :: non_neg_integer, acc :: term})

  @typedoc "Bitblock definition"
  @type t :: %{optional(atom) => any, __struct__: atom}

  ## Callbacks

  @doc """
  Encodes the given data type into a bitstring.

  ## Example

      iex> block = %MyBlock{seg1: 1, seg: 2}
      iex> MyBlock.encode(block)
  """
  @callback encode(t) :: bitstring

  @doc """
  Decodes the given bitstring into the corresponding data type.

  ## Example

      iex> block = %MyBlock{seg1: 1, seg: 2}
      iex> bits = MyBlock.encode(block)
      iex> MyBlock.decode(bits)
  """
  @callback decode(input :: bitstring, acc :: term, dynamic_size_resolver) :: term

  ## API

  alias __MODULE__
  alias __MODULE__.{Array, DynamicSegment}

  @doc """
  Defines a bit-block struct with a name and segment definitions.
  """
  defmacro defblock(name, opts \\ [], do: block) do
    prelude =
      quote do
        :ok = Module.put_attribute(__MODULE__, :block_segments, [])
        :ok = Module.put_attribute(__MODULE__, :dynamic_segments, [])

        name = unquote(name)

        unquote(block)
      end

    postlude =
      quote unquote: false, bind_quoted: [opts: opts] do
        @behaviour Bitcraft.BitBlock

        segments = Module.get_attribute(__MODULE__, :block_segments, [])

        struct_segments =
          Enum.reduce(
            segments ++ [block_segment(name: :leftover, default: <<>>)],
            [],
            fn block_segment(name: name, type: type, default: default), acc ->
              [{name, default} | acc]
            end
          )

        # define struct
        @enforce_keys Keyword.get(opts, :enforce_keys, [])
        defstruct struct_segments

        # maybe define default data type
        if Keyword.get(opts, :typespec, true) == true do
          @type t :: %__MODULE__{}
        end

        # build encoding expressions for encode/decode functions
        {bit_expr, map_expr} = BitBlock.build_encoding_exprs(segments, "", "")

        ## Encoding Functions

        @doc false
        def decode(unquote(bit_expr)) do
          Map.put(unquote(map_expr), :__struct__, __MODULE__)
        end

        def decode(unquote(bit_expr), acc_in, fun) when is_function(fun, 3) do
          struct = Map.put(unquote(map_expr), :__struct__, __MODULE__)
          BitBlock.decode_segments(@dynamic_segments, struct, acc_in, fun)
        end

        if length(@dynamic_segments) > 0 do
          @doc false
          def encode(data) do
            BitBlock.encode_segments(@block_segments, data)
          end
        else
          @doc false
          def encode(unquote(map_expr)) do
            unquote(bit_expr)
          end
        end

        ## Reflection Functions

        @doc false
        def __bit_block__(:name), do: unquote(name)

        def __bit_block__(:segments) do
          for block_segment(name: name) <- unquote(Macro.escape(@block_segments)), do: name
        end

        @doc false
        def __bit_block__(:segment_info, segment) do
          case :lists.keyfind(segment, 2, @block_segments) do
            false -> nil
            rec -> segment_to_map(rec)
          end
        end

        ## Private

        defp segment_to_map(rec) do
          %{
            name: block_segment(rec, :name),
            size: block_segment(rec, :size),
            type: block_segment(rec, :type),
            sign: block_segment(rec, :sign),
            endian: block_segment(rec, :endian),
            default: block_segment(rec, :default)
          }
        end
      end

    quote do
      unquote(prelude)
      unquote(postlude)
    end
  end

  @doc """
  Internal helper for decoding the block segments.
  """
  @spec decode_segments([block_segment], map, term, dynamic_size_resolver) :: map
  def decode_segments(block_segments, struct, acc_in, fun) do
    block_segments
    |> Enum.reduce(
      {struct, acc_in},
      fn block_segment(name: name, type: type, sign: sign, endian: endian), {data_acc, cb_acc} ->
        # exec callback
        {size, cb_acc} = fun.(data_acc, name, cb_acc)

        # parse segment bits
        {value, bits} = Bitcraft.decode_segment(data_acc.leftover, size, type, sign, endian)

        # update decoded data
        data_acc = %{
          data_acc
          | name => %DynamicSegment{
              value: value,
              size: size
            },
            leftover: bits
        }

        {data_acc, cb_acc}
      end
    )
    |> elem(0)
  end

  @doc """
  Internal helper for encoding the block segments.
  """
  @spec encode_segments([block_segment], map) :: bitstring
  def encode_segments(block_segments, data) do
    Enum.reduce(block_segments, <<>>, fn
      block_segment(size: nil), acc ->
        acc

      block_segment(name: name, size: :dynamic, type: type, sign: sign, endian: endian), acc ->
        case Map.fetch!(data, name) do
          %DynamicSegment{value: value, size: size} ->
            value = Bitcraft.encode_segment(value, size, type, sign, endian)
            <<acc::bitstring, value::bitstring>>

          nil ->
            acc

          value ->
            raise ArgumentError,
                  "dynamic segment #{name} is expected to be of type " <>
                    "#{DynamicSegment}, but got: #{inspect(value)}"
        end

      block_segment(name: name, size: size, type: type, sign: sign, endian: endian), acc ->
        value =
          data
          |> Map.fetch!(name)
          |> Bitcraft.encode_segment(size, type, sign, endian)

        <<acc::bitstring, value::bitstring>>
    end)
  end

  @doc """
  Defines a segment on the block with a given `name` and `size`.

  See `Kernel.SpecialForms.<<>>/1` for more information about the
  segment types, size, unit, and so on.

  ## Options

    * `:type` - Defines the segment data type the set of bits will be
      mapped to. See `Kernel.SpecialForms.<<>>/1` for more information
      about the segment data types. Defaults to `:integer`.

    * `:sign` - Applies only to integers and defines whether the integer
      is `:signed` or `:unsigned`. Defaults to `:unsigned`.

    * `:endian` - Applies to `utf32`, `utf16`, `float`, `integer`.
      Defines the endianness, `:big` or `:little`. Defaults to `:big`.

    * `:default` - Sets the default value on the block and the struct.
      The default value is calculated at compilation time, so don't use
      expressions for generating values dynamically as they would then
      be the same for all records. Defaults to `nil`.
  """
  defmacro segment(name, size \\ nil, opts \\ []) do
    quote do
      BitBlock.__segment__(__MODULE__, unquote(name), unquote(size), unquote(opts))
    end
  end

  @doc """
  Same as `segment/3`, but automatically generates a **dynamic**
  segment with the type `Bitcraft.BitBlock.Array.t()`.

  The size of the array-type segment in bits has to be calculated
  dynamically during the decoding, and the length of the array will
  be `segment_size/element_size`. This process is performs automatically
  during the decoding. hence, it is important to set the right
  `element_size` and also implement properly the callback to calculate
  the segment size. See `Bitcraft.BitBlock.dynamic_size_resolver()`.

  ## Options

  Options are the same as `segment/3`, and additionally:

    * `:element_size` - The size in bits of each array element.
      Defaults to `8`.

  **NOTE:** The `:type` is the same as `segment/3` BUT it applies to the
  array element.
  """
  defmacro array(name, opts \\ []) do
    {type, opts} = Keyword.pop(opts, :type, :integer)
    {size, opts} = Keyword.pop(opts, :element_size, 8)
    opts = [type: %Array{type: type, element_size: size}] ++ opts

    quote do
      BitBlock.__segment__(
        __MODULE__,
        unquote(name),
        :dynamic,
        unquote(Macro.escape(opts))
      )
    end
  end

  @doc """
  This is a helper function used internally for building a block segment.
  """
  @spec __segment__(module, atom, non_neg_integer, Keyword.t()) :: :ok
  def __segment__(mod, name, size, opts) do
    segment =
      block_segment(
        name: name,
        size: size,
        type: Keyword.get(opts, :type, :integer),
        sign: Keyword.get(opts, :sign, :unsigned),
        endian: Keyword.get(opts, :endian, :big),
        default: Keyword.get(opts, :default, nil)
      )

    if size == :dynamic do
      dynamic_segments = Module.get_attribute(mod, :dynamic_segments, [])
      Module.put_attribute(mod, :dynamic_segments, dynamic_segments ++ [segment])
    end

    block_segments = Module.get_attribute(mod, :block_segments, [])
    Module.put_attribute(mod, :block_segments, block_segments ++ [segment])
  end

  ## Helpers

  @doc """
  This is a helper function used internally for building the encoding
  expressions.
  """
  @spec build_encoding_exprs([block_segment], String.t(), String.t()) ::
          {bin_expr_ast :: term, map_expr_ast :: term}
  def build_encoding_exprs([], bin, map) do
    bin_expr =
      "<<"
      |> Kernel.<>(bin)
      |> Kernel.<>("leftover::bitstring")
      |> Kernel.<>(">>")
      |> Code.string_to_quoted!()

    map_expr =
      "%{"
      |> Kernel.<>(map)
      |> Kernel.<>("leftover: leftover")
      |> Kernel.<>("}")
      |> Code.string_to_quoted!()

    {bin_expr, map_expr}
  end

  def build_encoding_exprs([block_segment(name: name, size: size) = segment | segments], bin, map)
      when is_integer(size) do
    build_encoding_exprs(
      segments,
      bin <> "#{name}::" <> build_modifier(segment) <> ", ",
      map <> "#{name}: #{name}, "
    )
  end

  def build_encoding_exprs(
        [block_segment(name: name, size: size, default: default) | segments],
        bin,
        map
      )
      when is_atom(size) do
    build_encoding_exprs(segments, bin, map <> "#{name}: #{inspect(default)}, ")
  end

  ## Private

  # Helper function used internally for building bitstring modifier.
  defp build_modifier(block_segment(type: type, sign: sign, endian: endian, size: size))
       when type in [:integer, :float] do
    "#{type}-#{sign}-#{endian}-size(#{size})"
  end

  defp build_modifier(block_segment(type: type, size: size))
       when type in [:bitstring, :bits, :binary, :bytes] do
    "#{type}-size(#{size})"
  end

  defp build_modifier(block_segment(type: type, endian: endian))
       when type in [:utf8, :utf16, :utf32] do
    "#{type}-#{endian}"
  end
end
