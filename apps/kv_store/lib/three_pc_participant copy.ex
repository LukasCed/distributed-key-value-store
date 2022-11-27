# defmodule KVStore.ThreePcParticipant2 do

#   def transaction(:init, tx, txid) do
#     if validate(tx, txid) do
#       write_log(txid, tx, "phase12")
#       :agree

#       receive do
#         :prepare -> "prepare"
#         :abort -> "abort"
#         _ -> "something else"
#       end
#     end
#   end

#   defp validate(txid, _tx) do

#   end

#   defp write_log(txid, tx, msg) do
#     File.write("tx_participant_log", txid <> ";" <> to_string(tx) <> ";" <> msg <> "\r\n", [:append])
#   end

#   defp to_string_(_tx) do
#     "transaction"
#   end
# end
