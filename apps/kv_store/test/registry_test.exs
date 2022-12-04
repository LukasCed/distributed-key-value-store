defmodule KVStore.NodeTest do
  use ExUnit.Case, async: true

  setup context do
    _ = start_supervised!({KVStore.Node, name: context.test})
    %{registry: context.test}
  end

  test "spawns tables", %{registry: registry} do
    assert KVStore.Node.lookup(registry, "shopping") == :error

    KVStore.Node.create(registry, "shopping")
    assert {:ok, table} = KVStore.Node.lookup(registry, "shopping")

    KVStore.table().put(table, "milk", 1)
    assert KVStore.table().get(table, "milk") == 1
  end

  test "removes tables on exit", %{registry: registry} do
    KVStore.Node.create(registry, "shopping")
    {:ok, table} = KVStore.Node.lookup(registry, "shopping")
    Agent.stop(table)

    # Do a call to ensure the registry processed the DOWN message
    _ = KVStore.Node.create(registry, "bogus")
    assert KVStore.Node.lookup(registry, "shopping") == :error
  end

  test "removes table on crash", %{registry: registry} do
    KVStore.Node.create(registry, "shopping")
    {:ok, table} = KVStore.Node.lookup(registry, "shopping")

    # Stop the table with non-normal reason
    Agent.stop(table, :shutdown)

    # Do a call to ensure the registry processed the DOWN message
    _ = KVStore.Node.create(registry, "bogus")
    assert KVStore.Node.lookup(registry, "shopping") == :error
  end

  test "table can crash at any time", %{registry: registry} do
    KVStore.Node.create(registry, "shopping")
    {:ok, table} = KVStore.Node.lookup(registry, "shopping")

    # Simulate a table crash by explicitly and synchronously shutting it down
    Agent.stop(table, :shutdown)

    # Now trying to call the dead process causes a :noproc exit
    catch_exit(KVStore.table().put(table, "milk", 3))
  end
end
