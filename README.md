# Bitcraft
> A toolkit for bit-strings and DSL for binary protocols bit-blocks.

![CI](https://github.com/alboratech/bitcraft/workflows/CI/badge.svg)
[![Coverage Status](https://img.shields.io/coveralls/alboratech/bitcraft.svg)](https://coveralls.io/github/alboratech/bitcraft)
[![Hex Version](https://img.shields.io/hexpm/v/bitcraft.svg)](https://hex.pm/packages/bitcraft)
[![Docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/bitcraft)
[![License](https://img.shields.io/hexpm/l/bitcraft.svg)](LICENSE)

When working with binary protocols we usually have to implement encoding and
decoding functions for the different type of messages the protocol supports.
Despite parsing binary protocols is relatively easy in Elixir/Erlang using
binary pattern-matching (and one of the greatest features in Elixir/Erlang),
it might be tedius implement X number of parsing functions to support the
protocol messages, we may ending up with a lot of similar binary matching
all over the code, which is not bad, but what if we could avoid it?
What if we had a toolkit like **Ecto** to define parseable bit-blocks,
commonly used in binary protocols? This is where **Bitcraft** comes in!

**Bitcraft** provides a DSL for defining parseable binary blocks or messages.
You just need to define the bit-block for your message, adding the segments
with their names, sizes and properties, and then **Bitcraft** generates the
encoding and decoding functions automatically.

## Installation

You need to add `bitcraft` as a dependency to your `mix.exs` file.

```elixir
def deps do
  [
    {:bitcraft, "~> 0.1.0"}
  ]
end
```

## Getting started

Let's start defining the bit-block for a simple message:

```elixir
defmodule MyBlock do
  import Bitcraft.BitBlock

  defblock "my-block" do
    segment :header, 5, type: :binary
    segment :s1, 4, default: 1
    segment :s2, 8, default: 1, sign: :signed
    segment :tail, 3, type: :binary
  end
end
```

After compile your code, you will be able to run:

```elixir
iex> data = %MyBlock{header: "begin", s1: 3, s2: -3, tail: "end"}
iex> bits = MyBlock.encode(block)
<<98, 101, 103, 105, 110, 63, 214, 86, 230, 4::size(4)>>

iex> MyBlock.decode(bits)
%MyBlock{header: "begin", leftover: "", s1: 3, s2: -3, tail: "end"}
```

> See `Bitcraft.BitBlock.defblock/3` and `Bitcraft.BitBlock.segment/3`
  for more information.

### Working with dynamic blocks

For this example let's define an IPv4 datagram, which has a dynamic part:

```elixir
defmodule IpDatagram do
  import Bitcraft.BitBlock

  defblock "IP-datagram" do
    segment :vsn, 4
    segment :hlen, 4
    segment :srvc_type, 8
    segment :tot_len, 16
    segment :id, 16
    segment :flags, 3
    segment :frag_off, 13
    segment :ttl, 8
    segment :proto, 8
    segment :hdr_chksum, 16, type: :bits
    segment :src_ip, 32, type: :bits
    segment :dst_ip, 32, type: :bits
    segment :opts, :dynamic, type: :bits
    segment :data, :dynamic, type: :bits
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
```

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

```elixir
IpDatagram.decode(bits, :erlang.bit_size(bits), &IpDatagram.calc_size/3)
```

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

It is time to try it out! First of all, let's create a `IpDatagram` data type
with valid data:

```elixir
iex> dgram = %IpDatagram{
...>   vsn: 4,
...>   hlen: 6,
...>   srvc_type: 8,
...>   tot_len: 100,
...>   id: 1,
...>   flags: 1,
...>   frag_off: 1,
...>   ttl: 32,
...>   proto: 6,
...>   hdr_chksum: <<1, 1>>,
...>   src_ip: <<10, 10, 10, 5>>,
...>   dst_ip: <<10, 10, 10, 6>>,
...>   opts: %Bitcraft.BitBlock.DynamicSegment{
...>     value: <<10, 10, 10, 1>>,
...>     size: 32
...>   },
...>   data: %Bitcraft.BitBlock.DynamicSegment{
...>     value: "ping",
...>     size: 32
...>   }
...> }
```

As you notice, for the dynamic segments we use the data type
`Bitcraft.BitBlock.DynamicSegment` type, with the corresponding value and size
in bits. This will tell `Bitcraft` how the block should be encoded. This is the
way to set dynamic segments, the value cannot be assigned directly, it is to be
encapsulated within this data type with the value and size.

Now let's encode it:

```elixir
iex> bits = IpDatagram.encode(dgram)
<<70, 8, 0, 100, 0, 1, 32, 1, 32, 6, 1, 1, 10, 10, 10, 5, 10, 10, 10, 6, 10, 10,
  10, 1, 112, 105, 110, 103>>
```

Finally, for decoding it, we have to use the callback to resolve the dynamic
sizes, which was defined previously within the module `IpDatagram.calc_size/3`.

```elixir
iex> IpDatagram.decode(bits, :erlang.bit_size(bits), &IpDatagram.calc_size/3)
%IpDatagram{
  data: %Bitcraft.BitBlock.DynamicSegment{size: 32, value: "ping"},
  dst_ip: <<10, 10, 10, 6>>,
  flags: 1,
  frag_off: 1,
  hdr_chksum: <<1, 1>>,
  hlen: 6,
  id: 1,
  leftover: "",
  opts: %Bitcraft.BitBlock.DynamicSegment{size: 32, value: <<10, 10, 10, 1>>},
  proto: 6,
  src_ip: <<10, 10, 10, 5>>,
  srvc_type: 8,
  tot_len: 100,
  ttl: 32,
  vsn: 4
}
```

## Arrays

Sometimes we may also want to parse a segment of bits as an array, for example,
suppose we have a dynamic segment but we want to parse it as a list of integers
of 16 bits, what variates is the amount of them (the length of the array).
So, if the size of the segment is calculated as 64 bits, we expect an array
of 4 integers of 16 bits.

First of all, let us define a block with an array-type segment:

```elixir
defmodule TestBlock do
  import Bitcraft.BitBlock

  defblock "test-block" do
    segment :a, 8
    segment :b, 8
    array :list, type: :integer, element_size: 16, sign: :signed
  end

  # Size resolver for dynamic segments invoked during the decoding
  def calc_size(%__MODULE__{a: a, b: b}, :list, acc) do
    {a + b, acc}
  end
end
```

As you may notice, the field `:list` is defined as array-type in the form:

```elixir
array :list, type: :integer, element_size: 16, sign: :signed
```

The first argument is the name of the segment, then we pass the options.
The `type: :integer` defines the the type for the array elements, and
`element_size: 16` defines that each element of the array must have
16 bits size. The rest of the options are the same and apply to the
array elements.

> See `Bitcraft.BitBlock.array/2` and `Bitcraft.BitBlock.segment/3`.

Now, let's try it out:

```elixir
iex> data = %TestBlock{
...>   a: 32,
...>   b: 32,
...>   list: %Bitcraft.BitBlock.DynamicSegment{value: [1, 2, 3, 4], size: 64}
}
iex> encoded = TestBlock.encode(data)
<<32, 32, 0, 1, 0, 2, 0, 3, 0, 4>>
iex> TestBlock.decode(encoded, %{}, &TestBlock.calc_size/3)
%TestBlock{
  a: 32,
  b: 32,
  leftover: "",
  list: %Bitcraft.BitBlock.DynamicSegment{size: 64, value: [1, 2, 3, 4]}
}
```

## Contributing

Contributions to Bitcraft are very welcome and appreciated!

Use the [issue tracker](https://github.com/alboratech/bitcraft/issues) for bug
reports or feature requests. Open a
[pull request](https://github.com/alboratech/bitcraft/pulls)
when you are ready to contribute.

When submitting a pull request you should not update the
[CHANGELOG.md](CHANGELOG.md), and also make sure you test
your changes thoroughly, include unit tests
alongside new or changed code.

Before to submit a PR it is highly recommended to run `mix check` and ensure all
checks run successfully.

## Copyright and License

Copyright (c) 2020, Carlos Bolaños.

Copyright (c) 2021, Albora Technologies Ltd.

Bitcraft source code is licensed under the [MIT License](LICENSE).
