defmodule Apex.Policy.Engine do
  use GenServer

  alias Apex.Policy.Types.{Decision, Rule}

  @persistent_term_key {:apex, :policy_rules}

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def rules do
    :persistent_term.get(@persistent_term_key, [])
  end

  def put_rules(rules) when is_list(rules) do
    GenServer.call(__MODULE__, {:put_rules, rules})
  end

  def evaluate(capability, request) do
    capability_name = fetch(capability, :name)
    effect_type = fetch(capability, :effect_type)
    workspace_id = fetch(request, :workspace_id)
    resource_scope = fetch(capability, :resource_scope)

    matched =
      rules()
      |> Enum.find(fn %Rule{} = rule ->
        capability_match?(rule.capability_pattern, capability_name) and
          effect_type_match?(rule.effect_types, effect_type) and
          scope_match?(rule.workspace_scope, workspace_id) and
          scope_match?(rule.resource_scope, resource_scope)
      end)

    case matched do
      %Rule{} = rule ->
        %Decision{
          decision: rule.decision,
          matched_rule: rule.id,
          rationale: rule.rationale,
          effect_type: effect_type
        }

      nil ->
        %Decision{
          decision: :deny,
          matched_rule: "implicit-deny",
          rationale: "No policy rule matched the request.",
          effect_type: effect_type
        }
    end
  end

  def init(_opts) do
    rules =
      Application.fetch_env!(:apex, :policy_rules)
      |> normalize_rules()

    :persistent_term.put(@persistent_term_key, rules)
    {:ok, %{rules: rules}}
  end

  def handle_call({:put_rules, rules}, _from, _state) do
    normalized = normalize_rules(rules)
    :persistent_term.put(@persistent_term_key, normalized)
    {:reply, :ok, %{rules: normalized}}
  end

  defp normalize_rules(rules) do
    Enum.map(rules, &to_rule/1)
  end

  defp to_rule(%Rule{} = rule), do: rule

  defp to_rule(attrs) when is_map(attrs) do
    %Rule{
      id: fetch(attrs, :id),
      capability_pattern: fetch(attrs, :capability_pattern),
      effect_types:
        fetch(attrs, :effect_types)
        |> Enum.map(&normalize_atom/1),
      workspace_scope: fetch(attrs, :workspace_scope),
      resource_scope: fetch(attrs, :resource_scope),
      decision: normalize_atom(fetch(attrs, :decision)),
      rationale: fetch(attrs, :rationale)
    }
  end

  defp capability_match?("*", _capability), do: true

  defp capability_match?(pattern, capability) do
    regex =
      pattern
      |> Regex.escape()
      |> String.replace("\\*", ".*")
      |> then(&("^" <> &1 <> "$"))
      |> Regex.compile!()

    Regex.match?(regex, capability)
  end

  defp effect_type_match?(types, effect_type) do
    Enum.member?(types, normalize_atom(effect_type))
  end

  defp scope_match?("*", _value), do: true
  defp scope_match?(pattern, value), do: capability_match?(pattern, value)

  defp fetch(map, key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp normalize_atom(value) when is_atom(value), do: value
  defp normalize_atom(value) when is_binary(value), do: String.to_atom(value)
end
