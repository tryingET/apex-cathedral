defmodule Apex.Runtime.CapabilityRegistry do
  use GenServer

  alias Apex.Audit.Logger, as: Audit
  alias Apex.Providers.MockAccount
  alias Apex.Resources.{WorkspaceFS, WorkspaceSQLite}
  alias Apex.Runtime.Types.Capability

  @persistent_term_key {:apex, :capabilities}

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def list do
    :persistent_term.get(@persistent_term_key, [])
  end

  def get(name) do
    Enum.find(list(), fn %Capability{name: capability_name} -> capability_name == name end)
  end

  def init(_opts) do
    capabilities = build_capabilities()
    :persistent_term.put(@persistent_term_key, capabilities)

    Enum.each(capabilities, fn capability ->
      Audit.emit(
        :capability_registered,
        %{capability: capability.name, effect_type: capability.effect_type},
        entity_type: "capability",
        entity_id: capability.name
      )
    end)

    {:ok, %{capabilities: capabilities}}
  end

  defp build_capabilities do
    [
      %Capability{
        name: "workspace.fs.read_file",
        description: "Read a file from the workspace filesystem.",
        input_schema: %{
          type: "object",
          required: ["path"],
          properties: %{path: %{type: "string"}}
        },
        output_schema: %{
          type: "object",
          properties: %{path: %{type: "string"}, content: %{type: "string"}, bytes: %{type: "integer"}}
        },
        effect_type: :read,
        destructive_flag: false,
        resource_scope: "workspace.fs",
        approval_requirement: :policy,
        provider: "core.workspace",
        handler: {:resource, WorkspaceFS, :read_file}
      },
      %Capability{
        name: "workspace.fs.write_file",
        description: "Write a file into the workspace filesystem.",
        input_schema: %{
          type: "object",
          required: ["path", "content"],
          properties: %{path: %{type: "string"}, content: %{type: "string"}}
        },
        output_schema: %{
          type: "object",
          properties: %{path: %{type: "string"}, bytes: %{type: "integer"}}
        },
        effect_type: :write,
        destructive_flag: false,
        resource_scope: "workspace.fs",
        approval_requirement: :policy,
        provider: "core.workspace",
        handler: {:resource, WorkspaceFS, :write_file}
      },
      %Capability{
        name: "workspace.sqlite.query",
        description: "Run a read-only SQL query against the workspace SQLite database.",
        input_schema: %{
          type: "object",
          required: ["sql"],
          properties: %{sql: %{type: "string"}, params: %{type: "array"}}
        },
        output_schema: %{
          type: "object",
          properties: %{columns: %{type: "array"}, rows: %{type: "array"}, row_count: %{type: "integer"}}
        },
        effect_type: :read,
        destructive_flag: false,
        resource_scope: "workspace.sqlite",
        approval_requirement: :never,
        provider: "core.workspace",
        handler: {:resource, WorkspaceSQLite, :query}
      },
      %Capability{
        name: "workspace.sqlite.execute",
        description: "Run a state-changing SQL statement against the workspace SQLite database.",
        input_schema: %{
          type: "object",
          required: ["sql"],
          properties: %{sql: %{type: "string"}, params: %{type: "array"}}
        },
        output_schema: %{
          type: "object",
          properties: %{changes: %{type: "integer"}, last_insert_rowid: %{type: "integer"}}
        },
        effect_type: :write,
        destructive_flag: false,
        resource_scope: "workspace.sqlite",
        approval_requirement: :policy,
        provider: "core.workspace",
        handler: {:resource, WorkspaceSQLite, :execute}
      },
      %Capability{
        name: "mock.account.get_profile",
        description: "Read the current mock account profile.",
        input_schema: %{type: "object", properties: %{}},
        output_schema: %{type: "object"},
        effect_type: :read,
        destructive_flag: false,
        resource_scope: "mock.account",
        approval_requirement: :never,
        provider: "mock.account",
        handler: {:provider, MockAccount, :get_profile}
      },
      %Capability{
        name: "mock.account.update_profile",
        description: "Update the current mock account profile.",
        input_schema: %{
          type: "object",
          required: ["patch"],
          properties: %{patch: %{type: "object"}}
        },
        output_schema: %{type: "object"},
        effect_type: :external_side_effect,
        destructive_flag: false,
        resource_scope: "mock.account",
        approval_requirement: :policy,
        provider: "mock.account",
        handler: {:provider, MockAccount, :update_profile}
      }
    ]
  end
end
