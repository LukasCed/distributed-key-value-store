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
    %{socket: socket}
  end

  test "transaction commit", %{socket: socket} do
    assert String.contains?(send_and_recv(socket, "TRANSACTION\r\n"), ["OK", "started"])
    assert String.contains?(send_and_recv(socket, "CREATE users\r\n"), ["OK"])
    assert String.contains?(send_and_recv(socket, "PUT users user1 {'name':'Ted'}\r\n"), ["OK"])
    assert String.contains?(send_and_recv(socket, "END\r\n"), ["OK"])

    # outside the transaction
    assert send_and_recv(socket, "GET users user1\r\n") == "OK: {'NAME':'TED'}\r\n"
  end


  test "transaction abort", %{socket: socket} do
    assert String.contains?(send_and_recv(socket, "TRANSACTION\r\n"), ["OK", "started"])
    assert String.contains?(send_and_recv(socket, "CREATE users\r\n"), ["OK", "no"])
    assert String.contains?(send_and_recv(socket, "PUT users user1 {'name':'Ted'}\r\n"), ["OK", "no"])
    assert String.contains?(send_and_recv(socket, "DELETE users3 user2\r\n"), ["OK", "no"])
    assert String.contains?(send_and_recv(socket, "END\r\n"), ["OK", "no"])

    # outside the transaction
    assert send_and_recv(socket, "GET users user1\r\n") == "ERROR: value in table USERS with the key USER1 not found\r\n"
  end

  defp send_and_recv(socket, command) do
    :ok = :gen_tcp.send(socket, command)
    {:ok, data} = :gen_tcp.recv(socket, 0, 1000)
    data
  end
end