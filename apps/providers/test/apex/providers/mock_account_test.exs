defmodule Apex.Providers.MockAccountTest do
  use ExUnit.Case, async: false

  alias Apex.Providers.MockAccount

  setup do
    root = Application.fetch_env!(:apex, :storage_root)
    File.rm_rf!(root)
    :ok
  end

  test "reads and dry-runs profile updates" do
    assert {:ok, profile} = MockAccount.get_profile("provider-test", %{}, %{})
    assert profile["plan"] == "free"

    assert {:ok, result} =
             MockAccount.update_profile(
               "provider-test",
               %{"patch" => %{"plan" => "pro"}},
               %{dry_run: true}
             )

    assert result[:dry_run] == true
    assert result[:next]["plan"] == "pro"

    assert {:ok, profile_after} = MockAccount.get_profile("provider-test", %{}, %{})
    assert profile_after["plan"] == "free"
  end
end
