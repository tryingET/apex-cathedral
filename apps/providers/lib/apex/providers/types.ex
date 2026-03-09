defmodule Apex.Providers.Types do
  defmodule Provider do
    @enforce_keys [:name, :description, :capabilities, :adapter_module]
    defstruct [:name, :description, :capabilities, :adapter_module]
  end
end
