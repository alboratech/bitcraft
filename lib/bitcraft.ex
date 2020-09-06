defmodule Bitcraft do
  @moduledoc """
  Commons.
  """

  use Bitwise
  use Bitcraft.Helpers

  @typedoc "Codable data types"
  @type bit_data :: integer | float | binary | bitstring | byte | char

  ## API

  @spec encode_bits(bit_data, Keyword.t()) :: bitstring
  def encode_bits(input, opts \\ []) do
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

    encode_bits(input, size, type, sign, endian)
  end

  def decode_segment(input, opts \\ []) do
    type = Keyword.get(opts, :type, :integer)
    sign = Keyword.get(opts, :sign, :unsigned)
    endian = Keyword.get(opts, :endian, :big)
    size = opts[:size] || byte_size(input) * 8

    decode_segment(input, size, type, sign, endian)
  end

  @spec count_ones(integer) :: integer
  def count_ones(integer) when is_integer(integer) do
    count_ones(integer, 0)
  end

  defp count_ones(0, count), do: count

  defp count_ones(integer, count) do
    count_ones(integer &&& integer - 1, count + 1)
  end
end
