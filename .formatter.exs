locals_without_parens = [
  # Bitcraft.BitBlock
  defblock: 2,
  defblock: 3,
  segment: 1,
  segment: 2,
  segment: 3,
  array: 1,
  array: 2
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  line_length: 100,
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens]
]
