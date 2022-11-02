defmodule KVStore.Validator do
  require Logger

  def validate_transactions(operations, {tables, refs, txs}) do
    Logger.debug("Validating some operations before answering")
    validity =
      (for {:do_delete, [table, key, _]} <- operations, do: validate_delete(operations, table, tables, key)) ++
      (for {:do_put, [table, key, value, _]} <- operations, do: validate_put(operations, table, tables, key, value))

    case :no in validity do
      true -> {:reply, :no, {tables, refs, txs}}
      false -> {:reply, :yes, {tables, refs, txs}}
    end
  end

  defp validate_delete(operations, table, tables, key) do
    Logger.debug("Validating delete")

    validity = [
      # check if there is the right table
      case lookup(tables, table) do
        {:ok, pid} ->
          # check if there is a record to delete the table
          case KVStore.Table.get(pid, key) do
            nil ->
              # or in the transactions
              case for {:do_put, [_, key_tx, _]} <- operations, key_tx == key, do: :ok do
                [] -> :no
                _ -> :yes
              end
            _ -> :yes
          end
        :error ->   # or in the transactions
          case for {:do_create, [table_tx, _]} <- operations, table_tx == table, do: :ok do
            [] -> :no
            _ -> :yes
          end
      end
    ]
    # at least one reason not to commit - answer no
    case :no in validity do
      true -> :no
      false -> :yes
    end
  end

  defp validate_put(operations, table, tables, _, _) do
    Logger.debug("Validating put")

    validity = [
      # check if there is the right table
      case lookup(tables, table) do
        {:ok, _} -> :yes
        :error ->  # or in the transactions
          case for {:do_create, [table_tx, _]} <- operations, table_tx == table, do: :ok do
            [] -> :no
            _ -> :yes
          end
      end
    ]

    # at least one reason not to commit - answer no
    case :no in validity do
      true ->
        Logger.debug("Put invalid")
        :no
      false ->
        Logger.debug("Put valid")
        :yes
    end
  end

  def lookup(tables, table) do
    Logger.debug("Looking up #{inspect(table)} in #{inspect(tables)}")
    # Check if there is a table existing
    case :ets.lookup(tables, table) do
      [{^table, pid}] ->
        Logger.debug("Table exists")
        {:ok, pid}

      [] ->
        Logger.debug("Table does not exist")
        :error
    end
  end
end
