defmodule FA.BucketTest do
  use ExUnit.Case, async: true

  setup do
    bucket = start_supervised!(FA.Bucket)
    %{bucket: bucket}
  end

  test "stores values by key", %{bucket: bucket} do
    assert FA.Bucket.get(bucket, "milk") == nil

    FA.Bucket.put(bucket, "milk", 3)
    assert FA.Bucket.get(bucket, "milk") == 3
  end

  test "deletes values by key", %{bucket: bucket} do
    FA.Bucket.put(bucket, "milk", 3)
    assert FA.Bucket.get(bucket, "milk") == 3

    FA.Bucket.delete(bucket, "milk")
    assert FA.Bucket.get(bucket, "milk") == nil

  end

  test "are temporary workers" do
    assert Supervisor.child_spec(FA.Bucket, []).restart == :temporary
  end


end
