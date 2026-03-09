defmodule Apex.Runtime.Id do
  def generate do
    12
    |> :crypto.strong_rand_bytes()
    |> Base.encode32(case: :lower, padding: false)
  end
end
