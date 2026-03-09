defmodule Apex.Policy.EngineTest do
  use ExUnit.Case, async: false

  alias Apex.Policy.Engine

  setup do
    original = Engine.rules()

    on_exit(fn ->
      Engine.put_rules(original)
    end)

    :ok
  end

  test "matches exact rules before wildcard deny" do
    Engine.put_rules([
      %{
        id: "allow-read",
        capability_pattern: "workspace.fs.read_file",
        effect_types: [:read],
        workspace_scope: "*",
        resource_scope: "workspace.fs",
        decision: :allow,
        rationale: "read allowed"
      },
      %{
        id: "deny-default",
        capability_pattern: "*",
        effect_types: [:read, :write, :destructive, :external_side_effect],
        workspace_scope: "*",
        resource_scope: "*",
        decision: :deny,
        rationale: "deny"
      }
    ])

    decision =
      Engine.evaluate(
        %{
          name: "workspace.fs.read_file",
          effect_type: :read,
          resource_scope: "workspace.fs"
        },
        %{workspace_id: "demo"}
      )

    assert decision.decision == :allow
    assert decision.matched_rule == "allow-read"
  end

  test "supports wildcard capability patterns" do
    Engine.put_rules([
      %{
        id: "approve-writes",
        capability_pattern: "workspace.fs.*",
        effect_types: [:write],
        workspace_scope: "*",
        resource_scope: "workspace.fs",
        decision: :approval_required,
        rationale: "approval"
      }
    ])

    decision =
      Engine.evaluate(
        %{
          name: "workspace.fs.write_file",
          effect_type: :write,
          resource_scope: "workspace.fs"
        },
        %{workspace_id: "demo"}
      )

    assert decision.decision == :approval_required
  end

  test "denies when no rule matches" do
    Engine.put_rules([])

    decision =
      Engine.evaluate(
        %{
          name: "unknown.capability",
          effect_type: :external_side_effect,
          resource_scope: "unknown"
        },
        %{workspace_id: "demo"}
      )

    assert decision.decision == :deny
    assert decision.matched_rule == "implicit-deny"
  end
end
