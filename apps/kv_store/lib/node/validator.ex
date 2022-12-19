defmodule KVStore.Validator do
  require Logger

  def validate_transactions(path, transactions) do
    Logger.debug("Validating queries")

    validity = for {:delete, args} <- transactions, do: validate_delete(path, args, transactions)

    :no not in validity
  end

  defp validate_delete(path, {table, key}, other_queries) do
    Logger.debug("Validating delete")

    validity = [
      # check if there is the record
      case KVStore.Database.perform_op(:get, to_string(path), {table, key}) do
        {:ok, _} ->
          Logger.debug("Found record in table")
          :yes

        # or in the transactions
        {:error, _} ->
          # check create
          Logger.debug("Didn't find record in table")

          case for {:create, {table_tx}} <- other_queries, table_tx == table, do: :ok do
            [] ->
              Logger.debug("No create statement found either")
              :no

            _ ->
              Logger.debug("Found a create table statement")
              # check put
              case for {:put, {table_tx, key_tx, _}} <- other_queries,
                       table_tx == table,
                       key_tx == key,
                       do: :ok do
                [] ->
                  Logger.debug("No put statement found")
                  :no

                _ ->
                  Logger.debug("Put statement found")
                  :yes
              end
          end
      end
    ]

    # at least one reason not to commit - answer no
    case :no in validity do
      true -> :no
      false -> :yes
    end
  end
end
