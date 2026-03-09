defmodule Apex.Policy.Types do
  defmodule Rule do
    @enforce_keys [
      :id,
      :capability_pattern,
      :effect_types,
      :workspace_scope,
      :resource_scope,
      :decision,
      :rationale
    ]
    defstruct [
      :id,
      :capability_pattern,
      :effect_types,
      :workspace_scope,
      :resource_scope,
      :decision,
      :rationale
    ]
  end

  defmodule Decision do
    @enforce_keys [:decision, :matched_rule, :rationale, :effect_type]
    defstruct [:decision, :matched_rule, :rationale, :effect_type]
  end
end
