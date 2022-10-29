defmodule FA.RegistryTest do
  use ExUnit.Case, async: true

  setup context do
    _ = start_supervised!({FA.Registry, name: context.test})
    %{registry: context.test}
  end

  test "spawns buckets", %{registry: registry} do
    assert FA.Registry.lookup(registry, "shopping") == :error

    FA.Registry.create(registry, "shopping")
    assert {:ok, bucket} = FA.Registry.lookup(registry, "shopping")

    FA.Bucket.put(bucket, "milk", 1)
    assert FA.Bucket.get(bucket, "milk") == 1
  end

  test "removes buckets on exit", %{registry: registry} do
    FA.Registry.create(registry, "shopping")
    {:ok, bucket} = FA.Registry.lookup(registry, "shopping")
    Agent.stop(bucket)

    # Do a call to ensure the registry processed the DOWN message
    _ = FA.Registry.create(registry, "bogus")
    assert FA.Registry.lookup(registry, "shopping") == :error
  end


  test "removes bucket on crash", %{registry: registry} do
    FA.Registry.create(registry, "shopping")
    {:ok, bucket} = FA.Registry.lookup(registry, "shopping")

    # Stop the bucket with non-normal reason
    Agent.stop(bucket, :shutdown)

    # Do a call to ensure the registry processed the DOWN message
    _ = FA.Registry.create(registry, "bogus")
    assert FA.Registry.lookup(registry, "shopping") == :error
  end


  test "bucket can crash at any time", %{registry: registry} do
    FA.Registry.create(registry, "shopping")
    {:ok, bucket} = FA.Registry.lookup(registry, "shopping")

    # Simulate a bucket crash by explicitly and synchronously shutting it down
    Agent.stop(bucket, :shutdown)

    # Now trying to call the dead process causes a :noproc exit
    catch_exit FA.Bucket.put(bucket, "milk", 3)
  end


end
