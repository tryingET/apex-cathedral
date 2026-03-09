defmodule Apex.Gateway.RouterTest do
  use ExUnit.Case, async: false
  import Plug.Conn
  import Plug.Test

  alias Apex.Gateway.Router
  alias Apex.Runtime
  alias Apex.GatewayTestHelpers

  @opts Router.init([])

  setup do
    File.rm_rf!(Application.fetch_env!(:apex, :storage_root))
    Runtime.reset_state()
    :ok
  end

  test "lists capabilities" do
    conn = conn(:get, "/capabilities") |> Router.call(@opts)
    body = Jason.decode!(conn.resp_body)

    assert conn.status == 200
    assert Enum.any?(body["data"], &(&1["name"] == "workspace.fs.read_file"))
  end

  test "creates an execution through the API" do
    request =
      Jason.encode!(%{
        workspace_id: "api-demo",
        requested_by: "agent:api",
        capability: "workspace.sqlite.query",
        arguments: %{sql: "SELECT 1 AS ok", params: []}
      })

    conn =
      conn(:post, "/executions", request)
      |> put_req_header("content-type", "application/json")
      |> Router.call(@opts)

    body = Jason.decode!(conn.resp_body)

    assert conn.status == 201
    assert body["data"]["state"] == "RUNNING"

    execution_id = body["data"]["id"]

    assert GatewayTestHelpers.wait_until(fn ->
             Runtime.get_execution(execution_id).state == :completed
           end)
  end

  test "denies dry-run-only capability in execute mode" do
    request =
      Jason.encode!(%{
        workspace_id: "api-demo",
        requested_by: "agent:api",
        capability: "mock.account.update_profile",
        mode: "EXECUTE",
        arguments: %{patch: %{plan: "enterprise"}}
      })

    conn =
      conn(:post, "/executions", request)
      |> put_req_header("content-type", "application/json")
      |> Router.call(@opts)

    body = Jason.decode!(conn.resp_body)

    assert conn.status == 201
    assert body["data"]["state"] == "DENIED"
  end
end
