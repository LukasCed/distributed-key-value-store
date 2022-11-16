defmodule KVStoreTest do
  use ExUnit.Case

  @moduletag :capture_log

  setup do
    Application.stop(:kv_store)
    :ok = Application.start(:kv_store)
  end

  setup do
    opts = [:binary, packet: :line, active: false]
    {:ok, socket} = :gen_tcp.connect('localhost', 4040, opts)

    :ok = LocalCluster.start()
    nodes = LocalCluster.start_nodes("dsn-", 3)
    [n1, n2, n3] = nodes
    assert Node.ping(n1) == :pong
    assert Node.ping(n2) == :pong
    assert Node.ping(n3) == :pong

    %{socket: socket, nodes: [n1, n2, n3]}
  end

  test "transaction commit", %{socket: socket} do
    assert String.contains?(send_and_recv(socket, "TRANSACTION\r\n"), ["OK", "started"])
    assert String.contains?(send_and_recv(socket, "CREATE users\r\n"), ["OK", "no"])
    assert String.contains?(send_and_recv(socket, "PUT users user1 {'name':'Ted'}\r\n"), ["OK", "no"])
    assert String.contains?(send_and_recv(socket, "END\r\n"), ["OK", "no"])

    # outside the transaction
    assert send_and_recv(socket, "GET users user1\r\n") == "{\"name\": \"Ted\"}\r\n"
  end


  test "transaction abort", %{socket: socket} do
    assert send_and_recv(socket, "TRANSACTION\r\n") ==
      "OK\r\n"
    assert send_and_recv(socket, "CREATE users\r\n") ==
          "OK\r\n"
    assert send_and_recv(socket, "PUT users user1 {\"name\": \"Ted\"}\r\n") ==
          "OK\r\n"

    assert send_and_recv(socket, "DELETE users user2\r\n") ==
      "OK\r\n"

    assert send_and_recv(socket, "END\r\n") ==
    "OK\r\n"

    # outside the transaction
    assert send_and_recv(socket, "GET users user1\r\n") == "NOT OK\r\n"
  end

  defp send_and_recv(socket, command) do
    :ok = :gen_tcp.send(socket, command)
    {:ok, data} = :gen_tcp.recv(socket, 0, 1000)
    data
  end
end
