defmodule Bitcraft.BitBlockTest do
  @moduledoc false
  use ExUnit.Case
  doctest Bitcraft

  alias Bitcraft.BitBlock.DynamicSegment
  alias Bitcraft.TestBlocks.{DynamicBlock, IpDatagram, StaticBlock}

  describe "encode/decode" do
    test "static block works properly" do
      assert bits = StaticBlock.sample() |> StaticBlock.encode()
      assert data = StaticBlock.decode(bits)

      assert data == %StaticBlock{
               a: 3,
               b: 5,
               c: -10_000,
               header: "begin",
               leftover: "",
               tail: "end"
             }

      assert data |> StaticBlock.encode() == bits
    end

    test "dynamic block works properly" do
      assert bits = DynamicBlock.sample() |> DynamicBlock.encode()
      assert data = DynamicBlock.decode(bits, %{}, &DynamicBlock.callback/3)

      assert data == %DynamicBlock{
               header: "test",
               a: 3,
               b: 5,
               c: -10_000,
               tail: 120,
               d: %DynamicSegment{size: 4, value: 2},
               e: %DynamicSegment{size: 16, value: [1, -1, 2, -2]},
               leftover: "",
               extra: nil
             }

      assert data |> DynamicBlock.encode() == bits
    end

    test "IP datagram" do
      assert bits = IpDatagram.sample() |> IpDatagram.encode()
      assert data = IpDatagram.decode(bits, %{}, &IpDatagram.callback/3)

      assert data == %IpDatagram{
               data: %DynamicSegment{size: 32, value: "ping"},
               dst_ip: <<10, 10, 10, 6>>,
               flags: 1,
               frag_off: 1,
               hdr_chksum: <<1, 1>>,
               hlen: 6,
               id: 1,
               leftover: "",
               opts: %DynamicSegment{size: 32, value: <<10, 10, 10, 1>>},
               proto: 6,
               src_ip: <<10, 10, 10, 5>>,
               srvc_type: 8,
               tot_len: 100,
               ttl: 32,
               vsn: 4
             }

      assert data |> IpDatagram.encode() == bits
    end

    test "IP datagram without opts" do
      dgram = IpDatagram.sample()
      assert bits = IpDatagram.encode(%{dgram | hlen: 5, opts: nil})
      assert data = IpDatagram.decode(bits, :erlang.bit_size(bits), &IpDatagram.callback/3)

      assert data == %IpDatagram{
               data: %DynamicSegment{size: 32, value: "ping"},
               dst_ip: <<10, 10, 10, 6>>,
               flags: 1,
               frag_off: 1,
               hdr_chksum: <<1, 1>>,
               hlen: 5,
               id: 1,
               leftover: "",
               opts: %DynamicSegment{size: 0, value: ""},
               proto: 6,
               src_ip: <<10, 10, 10, 5>>,
               srvc_type: 8,
               tot_len: 100,
               ttl: 32,
               vsn: 4
             }

      assert data |> IpDatagram.encode() == bits
    end
  end

  describe "__bit_block__" do
    test "segments" do
      assert segments = DynamicBlock.__bit_block__(:segments)
      assert length(segments) == 8
      assert segments == [:header, :a, :b, :c, :tail, :d, :e, :extra]
    end

    test "segment_info" do
      refute DynamicBlock.__bit_block__(:segment_info, :invalid)

      assert DynamicBlock.__bit_block__(:segment_info, :header) == %{
               default: nil,
               endian: :big,
               name: :header,
               sign: :unsigned,
               size: 4,
               type: :binary
             }
    end
  end
end
