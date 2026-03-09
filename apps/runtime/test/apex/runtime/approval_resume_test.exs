defmodule Apex.Runtime.ApprovalResumeTest do
  use ExUnit.Case, async: false

  alias Apex.Runtime
  alias Apex.TestHelpers

  setup do
    File.rm_rf!(Application.fetch_env!(:apex, :storage_root))
    Runtime.reset_state()
    :ok
  end

  test "file writes pause for approval and resume" do
    assert {:ok, execution} =
             Runtime.request_execution(%{
               "workspace_id" => "demo",
               "requested_by" => "agent:writer",
               "capability" => "workspace.fs.write_file",
               "arguments" => %{
                 "path" => "notes/hello.txt",
                 "content" => "hello"
               }
             })

    assert execution.state == :pending_approval
    assert is_binary(execution.approval_id)

    assert {:ok, _approval} = Runtime.approve(execution.approval_id, "human:operator")

    assert TestHelpers.wait_until(fn ->
             Runtime.get_execution(execution.id).state == :completed
           end)

    file_path =
      Path.join([
        Application.fetch_env!(:apex, :storage_root),
        "workspaces",
        "demo",
        "fs",
        "notes",
        "hello.txt"
      ])

    assert File.read!(file_path) == "hello"
  end
end
