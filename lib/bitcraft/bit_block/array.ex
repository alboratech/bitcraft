defmodule Bitcraft.BitBlock.Array do
  @moduledoc """
  Defines the type array.
  """

  defstruct type: :integer, element_size: 8

  @type t :: %__MODULE__{
          type: Bitcraft.BitBlock.seg_type(),
          element_size: non_neg_integer
        }
end
