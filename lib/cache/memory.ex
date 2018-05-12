defmodule Tus.Cache.Memory do
  use GenServer

  # Public API ----------------------------------------------------------------

  def start_link(%{cache_name: cache_name}) do
    GenServer.start_link(
      __MODULE__,
      [
        {:ets_table_name, :tus_cache_table},
        {:log_limit, 1_000_000}
      ],
      name: cache_name
    )
  end

  def get(name, key) do
    case GenServer.call(name, {:get, key}) do
      [] -> nil
      [{_key, file}] -> file
    end
  end

  def put(name, key, file) do
    GenServer.call(name, {:set, key, file})
  end

  def delete(name, key) do
    GenServer.cast(name, {:delete, key})
  end

  # Server --------------------------------------------------------------------

  def handle_call({:get, key}, _from, state) do
    %{ets_table_name: ets_table_name} = state
    {:reply, :ets.lookup(ets_table_name, key), state}
  end

  def handle_call({:set, key, file}, _from, state) do
    %{ets_table_name: ets_table_name} = state
    true = :ets.insert(ets_table_name, {key, file})
    {:reply, file, state}
  end

  def handle_cast({:delete, key}, state) do
    %{ets_table_name: ets_table_name} = state
    :ets.delete(ets_table_name, key)
    {:noreply, state}
  end

  def init(args) do
    [{:ets_table_name, ets_table_name}, {:log_limit, log_limit}] = args

    :ets.new(ets_table_name, [:named_table, :set, :private])

    {:ok, %{log_limit: log_limit, ets_table_name: ets_table_name}}
  end
end
