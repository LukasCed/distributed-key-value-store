defmodule KVStoreTest do
  use ExUnit.Case, async: false
  import Mock

  @moduletag :capture_log

  setup do
    # kv_store
    :ok = LocalCluster.start()
    nodes = LocalCluster.start_nodes("dsn-", 2, applications: [])
    [n1, n2] = nodes
    assert Node.ping(n1) == :pong
    assert Node.ping(n2) == :pong

    file_path = Path.absname("db_logs")
    File.rm_rf(file_path)

    :rpc.call(n1, Application, :ensure_all_started, [:kv_store])
    :rpc.call(n2, Application, :ensure_all_started, [:kv_store])

    # kv_server
    Application.stop(:kv_server)
    Application.put_env(:kv_server, :port, 4040, persistent: true)
    {:ok, [:kv_server]} = Application.ensure_all_started(:kv_server)

    opts = [:binary, packet: :line, active: false]
    {:ok, socket} = :gen_tcp.connect('localhost', 4040, opts)
    %{socket: socket, node1: n1, node2: n2}
  end

  test "transaction commit", %{socket: socket} do
    assert String.contains?(send_and_recv(socket, "TRANSACTION\r\n"), ["OK", "started"])
    assert String.contains?(send_and_recv(socket, "CREATE users\r\n"), ["OK"])
    assert String.contains?(send_and_recv(socket, "PUT users user1 {'name':'Ted'}\r\n"), ["OK"])
    assert String.contains?(send_and_recv(socket, "CREATE users123\r\n"), ["OK"])

    assert String.contains?(send_and_recv(socket, "PUT users123 user1 {'name':'Todd'}\r\n"), [
             "OK"
           ])

    assert String.contains?(send_and_recv(socket, "DELETE users123 user1\r\n"), ["OK"])

    assert String.contains?(send_and_recv(socket, "END\r\n"), ["Transaction concluded\r\n"])

    # outside the transaction
    assert send_and_recv(socket, "GET users user1\r\n") == "{'NAME':'TED'}\r\n"
    assert send_and_recv(socket, "GET users123 user1\r\n") == "Not found\r\n"
  end

  test "transaction abort", %{socket: socket} do
    assert String.contains?(send_and_recv(socket, "TRANSACTION\r\n"), ["OK", "started"])
    assert String.contains?(send_and_recv(socket, "CREATE users\r\n"), ["OK", "no"])

    assert String.contains?(send_and_recv(socket, "PUT users user1 {'name':'Ted'}\r\n"), [
             "OK",
             "no"
           ])

    assert String.contains?(send_and_recv(socket, "DELETE users3 user2\r\n"), ["OK", "no"])
    assert String.contains?(send_and_recv(socket, "END\r\n"), ["Transaction concluded\r\n"])

    # outside the transaction
    assert send_and_recv(socket, "GET users user1\r\n") == "Not found\r\n"
  end

  test_with_mock "transaction coordinator crash init",
                 %{socket: socket},
                 KVServer.ThreePcCoordinator,
                 [:passthrough],
                 broadcast_init: fn _, _ -> Application.stop(:kv_server) end do
    assert String.contains?(send_and_recv(socket, "TRANSACTION\r\n"), ["OK", "started"])
    assert String.contains?(send_and_recv(socket, "CREATE users\r\n"), ["OK", "no"])

    assert String.contains?(send_and_recv(socket, "PUT users user1 {'name':'Ted'}\r\n"), [
             "OK",
             "no"
           ])

    # send message. here the process will crash and won't reply anything, so no response is expected
    send_no_rcv(socket, "END\r\n")
    # assert String.contains?(send_and_recv(socket, "END\r\n"), ["Transaction concluded\r\n"])

    # outside the transaction
    # here should assert that DB is empty
    # assert send_and_recv(socket, "GET users user1\r\n") == "Not found\r\n"

    # restart the server
    Process.sleep(1000)
    Application.put_env(:kv_server, :port, 4040, persistent: true)
    {:ok, _} = Application.ensure_all_started(:kv_server)
    opts = [:binary, packet: :line, active: false]
    {:ok, socket} = :gen_tcp.connect('localhost', 4040, opts)

    # entity still not found because crashed before sending "init" smsg
    assert send_and_recv(socket, "GET users user1\r\n") == "Not found\r\n"
  end

  test_with_mock "transaction coordinator crash commit",
                 %{socket: socket},
                 KVServer.ThreePcCoordinator,
                 [:passthrough],
                 broadcast_commit: fn tx_id ->
                   # need to only crash the first time..
                   if tx_id != "new_tx_id" do
                     Application.stop(:kv_server)
                   else
                     KVServer.ThreePcCoordinator.broadcast(:commit, tx_id)
                   end
                 end do
    assert String.contains?(send_and_recv(socket, "TRANSACTION\r\n"), ["OK", "started"])
    assert String.contains?(send_and_recv(socket, "CREATE users\r\n"), ["OK", "no"])

    assert String.contains?(send_and_recv(socket, "PUT users user1 {'name':'Ted'}\r\n"), [
             "OK",
             "no"
           ])

    # send message. here the process will crash and won't reply anything, so no response is expected
    send_no_rcv(socket, "END\r\n")
    # assert String.contains?(send_and_recv(socket, "END\r\n"), ["Transaction concluded\r\n"])

    # outside the transaction
    # here should assert that DB is empty
    # assert send_and_recv(socket, "GET users user1\r\n") == "Not found\r\n"

    # restart the server
    Process.sleep(1000)
    Application.put_env(:kv_server, :port, 4040, persistent: true)
    {:ok, _} = Application.ensure_all_started(:kv_server)
    opts = [:binary, packet: :line, active: false]
    {:ok, socket} = :gen_tcp.connect('localhost', 4040, opts)

    # entity still not found because crashed before sending "init" smsg
    assert send_and_recv(socket, "GET users user1\r\n") == "{'NAME':'TED'}\r\n"
  end

  defp send_and_recv(socket, command) do
    :ok = :gen_tcp.send(socket, command)
    {:ok, data} = :gen_tcp.recv(socket, 0, 1000)
    data
  end

  defp send_no_rcv(socket, command) do
    :gen_tcp.send(socket, command)
  end
end
