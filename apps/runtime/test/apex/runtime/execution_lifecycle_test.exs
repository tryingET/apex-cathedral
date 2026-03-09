defmodule Apex.Runtime.ExecutionLifecycleTest do
  use ExUnit.Case, async: false

  alias Apex.Runtime
  alias Apex.TestHelpers

  setup do
    File.rm_rf!(Application.fetch_env!(:apex, :storage_root))
    Runtime.reset_state()
    :ok
  end

  test "sqlite query transitions to completed" do
    assert {:ok, execution} =
             Runtime.request_execution(%{
               "workspace_id" => "demo",
               "requested_by" => "agent:analyst",
               "capability" => "workspace.sqlite.query",
               "arguments" => %{
                 "sql" => "SELECT 1 AS ok",
                 "params" => []
               }
             })

    assert execution.state == :running

    assert TestHelpers.wait_until(fn ->
             Runtime.get_execution(execution.id).state == :completed
           end)

    completed = Runtime.get_execution(execution.id)
    assert completed.result.output.row_count == 1
    assert completed.result.output.rows == [%{"ok" => 1}]
  end
end
