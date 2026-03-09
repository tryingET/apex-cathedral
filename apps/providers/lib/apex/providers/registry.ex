defmodule Apex.Providers.Registry do
  use GenServer

  alias Apex.Providers.MockAccount
  alias Apex.Providers.Types.Provider

  @persistent_term_key {:apex, :providers}

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def list do
    :persistent_term.get(@persistent_term_key, [])
  end

  def get(name) do
    Enum.find(list(), fn %Provider{name: provider_name} -> provider_name == name end)
  end

  def init(_opts) do
    providers = [
      %Provider{
        name: "mock.account",
        description: "A local mock account provider backed by the AccountSession resource.",
        capabilities: MockAccount.capability_names(),
        adapter_module: MockAccount
      }
    ]

    :persistent_term.put(@persistent_term_key, providers)
    {:ok, %{providers: providers}}
  end
end
