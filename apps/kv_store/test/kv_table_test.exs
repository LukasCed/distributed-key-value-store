defmodule KVStore.TableTest do
  use ExUnit.Case, async: true

  setup do
    table = start_supervised!(KVStore.Table)
    %{table: table}
  end

  test "stores values by key", %{table: table} do
    assert KVStore.Table.get(table, "user1") == nil

    KVStore.Table.put(table, "user1", "{height: 177}")
    assert KVStore.Table.get(table, "user1") == "{height: 177}"
  end

  test "deletes values by key", %{table: table} do
    KVStore.Table.put(table, "user1", "{height: 177}")
    assert KVStore.Table.get(table, "user1") == "{height: 177}"

    KVStore.Table.delete(table, "user1")
    assert KVStore.Table.get(table, "user1") == nil
  end

  test "are temporary workers" do
    assert Supervisor.child_spec(KVStore.Table, []).restart == :temporary
  end
end
