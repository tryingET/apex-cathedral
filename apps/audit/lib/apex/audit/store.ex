defmodule Apex.Audit.Store do
  use GenServer

  alias Apex.Audit.Types.Event

  @table :apex_audit_events

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def append(%Event{} = event) do
    GenServer.call(__MODULE__, {:append, event})
  end

  def query(filters \\ %{}) do
    @table
    |> :ets.tab2list()
    |> Enum.map(fn {_id, event} -> event end)
    |> Enum.filter(&matches_filters?(&1, filters))
    |> Enum.sort_by(& &1.inserted_at, :desc)
  end

  def subscribe do
    Registry.register(Apex.Audit.Registry, :events, [])
  end

  def init(_state) do
    path = Application.fetch_env!(:apex, :audit_log_path)
    File.mkdir_p!(Path.dirname(path))
    unless File.exists?(path), do: File.write!(path, "")

    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    load_existing(path)

    {:ok, %{path: path}}
  end

  def handle_call({:append, %Event{} = event}, _from, state) do
    persist!(state.path, event)
    :ets.insert(@table, {event.id, event})
    dispatch(event)
    {:reply, {:ok, event}, state}
  end

  defp load_existing(path) do
    path
    |> File.stream!()
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> Enum.each(fn line ->
      line
      |> Jason.decode!()
      |> event_from_map()
      |> then(fn event -> :ets.insert(@table, {event.id, event}) end)
    end)
  end

  defp persist!(path, %Event{} = event) do
    File.mkdir_p!(Path.dirname(path))
    encoded = Jason.encode!(event_to_map(event))
    File.write!(path, encoded <> "\n", [:append])
  end

  defp dispatch(event) do
    Registry.dispatch(Apex.Audit.Registry, :events, fn entries ->
      Enum.each(entries, fn {pid, _value} ->
        send(pid, {:audit_event, event})
      end)
    end)
  end

  defp event_from_map(map) do
    %Event{
      id: map["id"] || map[:id],
      type: normalize_atom(map["type"] || map[:type]),
      entity_type: map["entity_type"] || map[:entity_type],
      entity_id: map["entity_id"] || map[:entity_id],
      workspace_id: map["workspace_id"] || map[:workspace_id],
      actor: map["actor"] || map[:actor],
      payload: map["payload"] || map[:payload] || %{},
      inserted_at: map["inserted_at"] || map[:inserted_at]
    }
  end

  defp event_to_map(%Event{} = event) do
    %{
      id: event.id,
      type: Atom.to_string(event.type),
      entity_type: event.entity_type,
      entity_id: event.entity_id,
      workspace_id: event.workspace_id,
      actor: event.actor,
      payload: event.payload,
      inserted_at: event.inserted_at
    }
  end

  defp matches_filters?(event, filters) do
    Enum.all?(filters, fn
      {_key, nil} -> true
      {_key, ""} -> true
      {:type, type} -> Atom.to_string(event.type) == to_string(type)
      {"type", type} -> Atom.to_string(event.type) == to_string(type)
      {:workspace_id, value} -> event.workspace_id == value
      {"workspace_id", value} -> event.workspace_id == value
      {:entity_id, value} -> event.entity_id == value
      {"entity_id", value} -> event.entity_id == value
      _ -> true
    end)
  end

  defp normalize_atom(value) when is_atom(value), do: value
  defp normalize_atom(value) when is_binary(value), do: String.to_atom(value)
end
