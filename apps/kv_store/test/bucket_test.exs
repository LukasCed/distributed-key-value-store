defmodule KVStore.tableTest() do
  use ExUnit.Case, async: true

  setup do
    table = start_supervised!(KVStore.table())
    %{table: table}
  end

  test "stores values by key", %{table: table} do
    assert KVStore.table().get(table, "milk") == nil

    KVStore.table().put(table, "milk", 3)
    assert KVStore.table().get(table, "milk") == 3
  end

  test "deletes values by key", %{table: table} do
    KVStore.table().put(table, "milk", 3)
    assert KVStore.table().get(table, "milk") == 3

    KVStore.table().delete(table, "milk")
    assert KVStore.table().get(table, "milk") == nil
  end

  test "are temporary workers" do
    assert Supervisor.child_spec(KVStore.table(), []).restart == :temporary
  end
end
