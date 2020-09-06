defmodule Bitcraft.Helpers do
  @moduledoc """
  Module for building extra helper functions.
  """

  alias __MODULE__

  @doc false
  defmacro __using__(_opts) do
    quote do
      unquote(Helpers.build_segment_decoder())
    end
  end

  @doc """
  Helper function used internally for building `decode_segment/5` function.
  """
  @spec build_segment_decoder :: term
  def build_segment_decoder do
    sign_opts = [:signed, :unsigned]
    endian_opts = [:big, :little]

    int_exprs = integer_exprs(sign_opts, endian_opts)
    float_exprs = float_exprs(endian_opts)
    bin_exprs = bin_exprs()
    unicode_exprs = unicode_exprs(endian_opts)

    {dec_exprs, enc_exprs} =
      [int_exprs, float_exprs, bin_exprs, unicode_exprs]
      |> List.flatten()
      |> Enum.unzip()

    for expr <- dec_exprs ++ enc_exprs do
      expr = Code.string_to_quoted!(expr)

      quote do
        unquote(expr)
      end
    end
  end

  ## Internal Helpers

  defp integer_exprs(sign_opts, endian_opts) do
    for sign <- sign_opts, endian <- endian_opts do
      dec = """
      def decode_segment(bits, size, :integer, :#{sign}, :#{endian}) do
        <<segment::#{sign}-#{endian}-integer-size(size), rest::bits>> = bits
        {segment, rest}
      end
      """

      enc = """
      def encode_bits(var, size, :integer, :#{sign}, :#{endian}) do
        <<var::#{sign}-#{endian}-integer-size(size)>>
      end
      """

      {dec, enc}
    end
  end

  defp float_exprs(endian_opts) do
    for endian <- endian_opts do
      dec = """
      def decode_segment(bits, size, :float, _, :#{endian}) do
        <<segment::#{endian}-float-size(size), rest::bits>> = bits
        {segment, rest}
      end
      """

      enc = """
      def encode_bits(var, size, :float, _, :#{endian}) do
        <<var::#{endian}-float-size(size)>>
      end
      """

      {dec, enc}
    end
  end

  defp bin_exprs do
    for type <- [:bitstring, :bits, :binary, :bytes] do
      dec = """
      def decode_segment(bits, size, :#{type}, _, _) do
        <<segment::#{type}-size(size), rest::bits>> = bits
        {segment, rest}
      end
      """

      enc = """
      def encode_bits(var, _, :#{type}, _, _) do
        <<var::#{type}>>
      end
      """

      {dec, enc}
    end
  end

  defp unicode_exprs(endian_opts) do
    for type <- [:utf8, :utf16, :utf32], endian <- endian_opts do
      dec =
        if type == :utf8 do
          """
          def decode_segment(bits, _, :utf8, _, :#{endian}) do
            if is_integer(bits) do
              <<segment::#{type}-#{endian}, rest::bits>> = bits
              {segment, rest}
            else
              {:unicode.characters_to_binary(bits, :utf8), ""}
            end
          end
          """
        else
          """
          def decode_segment(bits, _, :#{type}, _, :#{endian}) do
            if is_integer(bits) do
              <<segment::#{type}-#{endian}, rest::bits>> = bits
              {segment, rest}
            else
              {:unicode.characters_to_binary(bits, {:#{type}, :#{endian}}), ""}
            end
          end
          """
        end

      enc = """
      def encode_bits(var, _, :#{type}, _, :#{endian}) do
        if is_integer(var) do
          <<var::#{type}-#{endian}>>
        else
          for << ch <- var >>, into: <<>>, do: <<ch::#{type}-#{endian}>>
        end
      end
      """

      {dec, enc}
    end
  end
end
