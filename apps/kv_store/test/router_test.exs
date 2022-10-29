defmodule FA.RouterTest do
  use ExUnit.Case

  setup_all do
    current = Application.get_env(:first_assignment, :routing_table)

    Application.put_env(:first_assignment, :routing_table, [
      {?a..?m, :"foo@DESKTOP-G5M07CN"},
      {?n..?z, :"bar@DESKTOP-G5M07CN"}
    ])

    on_exit fn -> Application.put_env(:first_assignment, :routing_table, current) end
  end

  @tag :distributed
  test "route requests across nodes" do
    assert FA.Router.route("hello", Kernel, :node, []) ==
             :"foo@DESKTOP-G5M07CN"
    assert FA.Router.route("world", Kernel, :node, []) ==
             :"bar@DESKTOP-G5M07CN"
  end

  test "raises on unknown entries" do
    assert_raise RuntimeError, ~r/could not find entry/, fn ->
      FA.Router.route(<<0>>, Kernel, :node, [])
    end
  end
end
