defmodule BitcraftTest do
  @moduledoc false
  use ExUnit.Case
  doctest Bitcraft

  describe "encode_bits/2 & decode_segment/2" do
    test "integers" do
      assert 5 |> Bitcraft.encode_bits() |> Bitcraft.decode_segment() == {5, ""}
      assert 3 |> Bitcraft.encode_bits(size: 4) |> Bitcraft.decode_segment(size: 4) == {3, ""}

      assert -3
             |> Bitcraft.encode_bits(size: 4, sign: :signed)
             |> Bitcraft.decode_segment(size: 4, sign: :signed) == {-3, ""}

      assert -3
             |> Bitcraft.encode_bits(size: 4, sign: :signed, endian: :little)
             |> Bitcraft.decode_segment(size: 4, sign: :signed, endian: :little) == {-3, ""}
    end

    test "floats" do
      assert 5.5 |> Bitcraft.encode_bits(type: :float) |> Bitcraft.decode_segment(type: :float) ==
               {5.5, ""}

      assert 3.3
             |> Bitcraft.encode_bits(size: 64, type: :float)
             |> Bitcraft.decode_segment(size: 64, type: :float) == {3.3, ""}

      assert -3.3
             |> Bitcraft.encode_bits(size: 64, type: :float, sign: :signed)
             |> Bitcraft.decode_segment(size: 64, type: :float, sign: :signed) == {-3.3, ""}

      assert -3.3
             |> Bitcraft.encode_bits(size: 64, type: :float, sign: :signed, endian: :little)
             |> Bitcraft.decode_segment(size: 64, type: :float, sign: :signed, endian: :little) ==
               {-3.3, ""}
    end

    test "binaries/bits" do
      assert "test"
             |> Bitcraft.encode_bits(type: :binary)
             |> Bitcraft.decode_segment(size: 4, type: :binary) == {"test", ""}

      assert <<1, 2, 3, 4>>
             |> Bitcraft.encode_bits(type: :bits)
             |> Bitcraft.decode_segment(size: 4, type: :binary) == {<<1, 2, 3, 4>>, ""}
    end

    test "utf8/utf16/utf32" do
      assert ?x
             |> Bitcraft.encode_bits(type: :utf8)
             |> Bitcraft.decode_segment(type: :utf8) == {"x", ""}

      assert "x"
             |> Bitcraft.encode_bits(type: :utf8)
             |> Bitcraft.decode_segment(type: :utf8) == {"x", ""}

      assert "foo"
             |> Bitcraft.encode_bits(type: :utf16)
             |> Bitcraft.decode_segment(type: :utf16) == {"foo", ""}

      assert "foo"
             |> Bitcraft.encode_bits(type: :utf32)
             |> Bitcraft.decode_segment(type: :utf32) == {"foo", ""}
    end
  end

  describe "count_ones/1" do
    test "returns the number of 1's bits for the given integer" do
      assert Bitcraft.count_ones(1) == 1
      assert Bitcraft.count_ones(3) == 2
      assert Bitcraft.count_ones(15) == 4
    end
  end
end
