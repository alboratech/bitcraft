defmodule Bitcraft.TestBlocks do
  @moduledoc false

  defmodule StaticBlock do
    @moduledoc false
    import Bitcraft.BitBlock

    defblock "test-block-1" do
      segment(:header, 5, type: :binary)
      segment(:a, 4, default: 1)
      segment(:b, 8, default: 1)
      segment(:c, 16, default: 1, sign: :signed)
      segment(:tail, 3, type: :binary)
    end

    def sample do
      %__MODULE__{
        header: "begin",
        a: 3,
        b: 5,
        c: -10_000,
        tail: "end"
      }
    end
  end

  defmodule DynamicBlock do
    @moduledoc false
    import Bitcraft.BitBlock

    alias Bitcraft.BitBlock.DynamicSegment

    defblock "test-block-1" do
      segment(:header, 4, type: :binary)
      segment(:a, 4, default: 1)
      segment(:b, 8, default: 1)
      segment(:c, 16, default: 1, sign: :signed)
      segment(:tail, 8, type: :utf8)
      segment(:d, :dynamic)
      segment(:e, :dynamic, sign: :signed)
      segment(:extra)
    end

    def callback(%__MODULE__{a: a, b: b}, :d, _acc) do
      offset = Bitcraft.count_ones(a * b) * 2
      {offset, %{offset: offset}}
    end

    def callback(%__MODULE__{}, :e, %{offset: offset} = acc) do
      {offset * 2, acc}
    end

    def sample do
      s1 = Bitcraft.count_ones(15) * 2
      s2 = s1 * 2

      %__MODULE__{
        header: "test",
        a: 3,
        b: 5,
        c: -10_000,
        d: %DynamicSegment{
          value: 128,
          size: s1
        },
        e: %DynamicSegment{
          value: 65_000,
          size: s2
        },
        tail: ?x
      }
    end
  end

  defmodule IpDatagram do
    @moduledoc false
    import Bitcraft.BitBlock

    alias Bitcraft.BitBlock.DynamicSegment

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

    def callback(%__MODULE__{hlen: hlen}, :opts, dgram_s)
        when hlen >= 5 and 4 * hlen <= dgram_s do
      opts_s = 4 * (hlen - 5)
      {opts_s * 8, dgram_s}
    end

    def callback(%__MODULE__{leftover: leftover}, :data, dgram_s) do
      data_s = :erlang.bit_size(leftover)
      {data_s, dgram_s}
    end

    def sample do
      %__MODULE__{
        vsn: 4,
        hlen: 6,
        srvc_type: 8,
        tot_len: 100,
        id: 1,
        flags: 1,
        frag_off: 1,
        ttl: 32,
        proto: 6,
        hdr_chksum: <<1, 1>>,
        src_ip: <<10, 10, 10, 5>>,
        dst_ip: <<10, 10, 10, 6>>,
        opts: %DynamicSegment{
          value: <<10, 10, 10, 1>>,
          size: 32
        },
        data: %DynamicSegment{
          value: "ping",
          size: 32
        }
      }
    end
  end
end
