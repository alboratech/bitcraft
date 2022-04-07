defmodule Bitcraft do
  @moduledoc """
  The following are the main Bitcraft components:

    * `Bitcraft.BitBlock` - This is the main Bitcraft component. It provides
      a DSL that allows to define bit-blocks with their segments (useful for
      building binary protocols) and automatically injects encoding and decoding
      functions for them.
    * `Bitcraft` - This is a helper module that provides utility functions to
      work with bit strings and binaries.

  """

  use Bitwise
  use Bitcraft.Helpers

  # Base data types for binaries
  @type base_type ::
          integer
          | float
          | binary
          | bitstring
          | byte
          | char

  @typedoc "Segment type"
  @type segment_type :: base_type | Bitcraft.BitBlock.Array.t()

  @typedoc "Codable segment type"
  @type codable_segment_type :: base_type | [base_type]

  ## API

  @doc """
  Encodes the given `input` into a bitstring.

  ## Options

    * `:size` - The size in bits for the input to encode. The default
      value depend on the type, for integer is 8, for float is 63, and for
      other data types is `nil`. If the `input` is a list, this option is
      skipped, since it is handled as array and the size will be
      `array_length * element_size`.

    * `:type` - The segment type given by `Bitcraft.segment_type()`.
      Defaults to `:integer`.

    * `:sign` - If the input is an integer, defines if it is `:signed`
      or `:unsigned`. Defaults to `:unsigned`.

    * `:endian` - Applies to `utf32`, `utf16`, `float`, `integer`.
      Defines the endianness, `:big` or `:little`. Defaults to `:big`.

  ## Example

      iex> Bitcraft.encode_segment(15)
      <<15>>

      iex> Bitcraft.encode_segment(255, size: 4)
      <<15::size(4)>>

      iex> Bitcraft.encode_segment(-3.3, size: 64, type: :float)
      <<192, 10, 102, 102, 102, 102, 102, 102>>

      iex> Bitcraft.encode_segment("hello", type: :binary)
      "hello"

      iex> Bitcraft.encode_segment(<<1, 2, 3>>, type: :bits)
      <<1, 2, 3>>

      iex> Bitcraft.encode_segment([1, -2, 3], type: %Bitcraft.BitBlock.Array{
      ...>   type: :integer, element_size: 4},
      ...>   sign: :signed
      ...> )
      <<30, 3::size(4)>>

  """
  @spec encode_segment(codable_segment_type, Keyword.t()) :: bitstring
  def encode_segment(input, opts \\ []) do
    type = Keyword.get(opts, :type, :integer)
    sign = Keyword.get(opts, :sign, :unsigned)
    endian = Keyword.get(opts, :endian, :big)
    size = Keyword.get(opts, :size)

    size =
      cond do
        is_nil(size) and is_integer(input) -> 8
        is_nil(size) and is_float(input) -> 64
        true -> size
      end

    encode_segment(input, size, type, sign, endian)
  end

  @doc """
  Returns a tuple `{decoded value, leftover}` where the first element is the
  decoded value from the given `input` (according to the given `otps` too)
  and the second element is the leftover.

  ## Options

    * `:size` - The size in bits to decode. Defaults to `byte_size(input) * 8`.
      If the type is `Bitcraft.BitBlock.Array.()`, the size should match with
      `array_length * element_size`.

    * `:type` - The segment type given by `Bitcraft.segment_type()`.
      Defaults to `:integer`.

    * `:sign` - If the input is an integer, defines if it is `:signed`
      or `:unsigned`. Defaults to `:unsigned`.

    * `:endian` - Applies to `utf32`, `utf16`, `float`, `integer`.
      Defines the endianness, `:big` or `:little`. Defaults to `:big`.

  ## Example

      iex> 3
      ...> |> Bitcraft.encode_segment(size: 4)
      ...> |> Bitcraft.decode_segment(size: 4)
      {3, ""}

      iex> -3.3
      ...> |> Bitcraft.encode_segment(size: 64, type: :float, sign: :signed)
      ...> |> Bitcraft.decode_segment(size: 64, type: :float, sign: :signed)
      {-3.3, ""}

      iex> "test"
      ...> |> Bitcraft.encode_segment(type: :binary)
      ...> |> Bitcraft.decode_segment(size: 4, type: :binary)
      {"test", ""}

      iex> <<1, 2, 3, 4>>
      ...> |> Bitcraft.encode_segment(type: :bits)
      ...> |> Bitcraft.decode_segment(size: 32, type: :bits)
      {<<1, 2, 3, 4>>, ""}

      iex> alias Bitcraft.BitBlock.Array
      iex> [1, 2]
      ...> |> Bitcraft.encode_segment(type: %Array{})
      ...> |> Bitcraft.decode_segment(size: 16, type: %Array{})
      {[1, 2], ""}
      iex> [3.3, -7.7, 9.9]
      ...> |> Bitcraft.encode_segment(
      ...>   type: %Array{type: :float, element_size: 64},
      ...>   sign: :signed
      ...> )
      ...> |> Bitcraft.decode_segment(
      ...>   size: 192,
      ...>   type: %Array{type: :float, element_size: 64},
      ...>   sign: :signed
      ...> )
      {[3.3, -7.7, 9.9], ""}

  """
  @spec decode_segment(bitstring, Keyword.t()) :: {codable_segment_type, bitstring}
  def decode_segment(input, opts \\ []) do
    type = Keyword.get(opts, :type, :integer)
    sign = Keyword.get(opts, :sign, :unsigned)
    endian = Keyword.get(opts, :endian, :big)
    size = opts[:size] || byte_size(input) * 8

    decode_segment(input, size, type, sign, endian)
  end

  @doc """
  Returns the number of `1`s in binary representation of the given `integer`.

  ## Example

      iex> Bitcraft.count_ones(15)
      4
      iex> Bitcraft.count_ones(255)
      8

  """
  @spec count_ones(integer) :: integer
  def count_ones(integer) when is_integer(integer) do
    count_ones(integer, 0)
  end

  defp count_ones(0, count), do: count

  defp count_ones(integer, count) do
    count_ones(integer &&& integer - 1, count + 1)
  end
end
