defmodule Apex.Runtime.ExecutionStore do
  use GenServer

  @table :apex_execution_runs

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def put(run) do
    :ets.insert(@table, {run.id, run})
    :ok
  end

  def get(id) do
    case :ets.lookup(@table, id) do
      [{^id, run}] -> run
      [] -> nil
    end
  end

  def list do
    @table
    |> :ets.tab2list()
    |> Enum.map(fn {_id, run} -> run end)
    |> Enum.sort_by(& &1.updated_at, :desc)
  end

  def clear do
    :ets.delete_all_objects(@table)
    :ok
  end

  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{table: @table}}
  end
end
