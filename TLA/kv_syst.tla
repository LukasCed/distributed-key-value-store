---------------------- MODULE kv_syst ----------------------
EXTENDS TLC
CONSTANT Values, Nodes, Tables, Keys, TxIds, NULL
VARIABLES msgs, proc, routes, txmanager, ackmanager
vars == <<msgs, proc, routes, txmanager, ackmanager>>

\* |-> vs ->?
\* f() vs f[] ?

Msgs == UNION {
    [type: {"node"}, operation: {"get"}, table: Tables, key: Keys, value: Values],
    [type: {"node"}, operation: {"put"}, table: Tables, key: Keys, value: Values],
    [type: {"node"}, operation: {"delete"}, table: Tables, key: Keys, value: Values],

    [type: {"broadcast"}, operation: {"create"}, table: Tables, key: Keys, value: Values],

    \* server *\
    [type: {"transaction"}],
    [type: {"prepare"}],
    [type: {"commit"}]
}

NodeMsgs == UNION {
    [type: {"ack_prepare"}],
    [type: {"ack_commit"}],
    [type: {"abort"}]
}

Routes == [Keys -> Nodes]
Processes == [Nodes -> [Tables -> [(Keys) -> (Values \union {NULL})]]]

Transactions == UNION {
    [type: {"ongoing"}, txid: TxIds],
    [type: {"commited"}, txid: TxIds],
    [type: {"aborted"}, txid: TxIds]
}

TxManager == [Nodes -> Transactions]
AckManager == [Nodes -> [Transactions -> NodeMsgs]]

TypeInvariant == 
    /\ proc \in Processes
    /\ msgs \subseteq Msgs \union NodeMsgs
    /\ routes \in Routes
    /\ txmanager \in TxManager
    /\ ackmanager \in AckManager

\* if there is two nodes that have same keys in any tables it must be the same node
NodesAlwaysHaveDifferentKeysInvariant == \A p \in Processes, t \in Tables, n1, n2 \in Nodes:
    /\ \A k \in DOMAIN p[n1][t] : \E l \in DOMAIN p[n2][t] : l = k => n1 = n2

TxTerminationProperty == \A n \in Nodes: TxManager[n].type = "ongoing" ~> TxManager[n].type \in {"commited", "aborted"}

Init ==
    /\ proc \in Processes
    /\ msgs = {}
    /\ routes \in Routes
    /\ txmanager \in TxManager \* how can I start with an empty state?
    /\ ackmanager \in AckManager

RcvNodeCreate(m) == \A n \in Nodes:
        /\ m.type = "broadcast"
        /\ m.operation = "create"

        /\ proc' = [proc EXCEPT ![n][m.table] = [k \in Keys |-> NULL]] 
        /\ msgs' = msgs \ {m}
        /\ UNCHANGED proc
        /\ UNCHANGED routes
        /\ UNCHANGED txmanager
        /\ UNCHANGED ackmanager

RcvNodeGet(m) == \E n \in Nodes:
        /\ m.type = "node"
        /\ m.operation = "get"
        /\ n = routes[m.key]

        /\ msgs' = msgs \ {m}
        /\ UNCHANGED proc
        /\ UNCHANGED routes
        /\ UNCHANGED txmanager
        /\ UNCHANGED ackmanager


RcvNodePut(m) == \E n \in Nodes:
        /\ m.type = "node"
        /\ m.operation = "put"
        /\ n = routes[m.key]

        /\ proc' = [proc EXCEPT ![n][m.table][m.key] = m.value]
        /\ msgs' = msgs \ {m}
        /\ UNCHANGED routes
        /\ UNCHANGED txmanager
        /\ UNCHANGED ackmanager

RcvNodeDelete(m) == \E n \in Nodes:
        /\ m.type = "node"
        /\ m.operation = "delete"
        /\ n = routes[m.key]

        /\ proc' = [proc EXCEPT ![n][m.table][m.key] = NULL]
        /\ msgs' = msgs \ {m}
        /\ UNCHANGED routes
        /\ UNCHANGED txmanager
        /\ UNCHANGED ackmanager

\* TxManager == [Nodes -> [Transactions -> (NodeMsgs \union {NULL})]]
\*--------------------------------- TRANSACTIONS \*---------------------------------*\
RcvNodeTransactionStart(m) == \E n \in Nodes, tx \in TxIds:
        /\ (txmanager = {} \/ (txmanager /= {} /\ txmanager[n].txid /= tx /\ txmanager[n].type /= "ongoing"))
        /\ m.type = "transaction"
        /\ msgs' = msgs \ {m}
        /\ txmanager' = txmanager \cup [n |-> [type |-> "ongoing", txid |-> tx]]
        /\ UNCHANGED routes
        /\ UNCHANGED proc
        /\ UNCHANGED ackmanager

RcvNodeTransactionPrepare(m) == \E n \in Nodes, t \in Transactions:
        /\ m.type = "prepare"
        /\ txmanager[n].txid = t.txid
        /\ txmanager[n].type = "ongoing"
        /\ ackmanager[n][t] = {}
        /\ msgs' = msgs \ {m}
        /\ ackmanager' = ackmanager \cup [n |-> [t |-> m \in {[type: {"prepare"}], [type: {"abort"}]}]]
        /\ UNCHANGED routes
        /\ UNCHANGED proc
        /\ UNCHANGED txmanager

RcvNodeTransactionCommit(m) == \E n \in Nodes, t \in Transactions:
        /\ m.type = "commit"
        /\ txmanager[n].txid = t.txid
        /\ txmanager[n].type = "ongoing"
        /\ ackmanager[n][t] /= {}
        /\ msgs' = msgs \ {m}
        /\ ackmanager' = ackmanager \cup [n |-> [t |-> m \in {[type: {"commit"}], [type: {"abort"}]}]]
        /\ UNCHANGED routes
        /\ UNCHANGED proc
        /\ UNCHANGED txmanager

\* sent by the server
\* bug
\* RcvNodeTransactionAbort(m) == \E n \in Nodes:
\*         /\ m.type = "transaction"
\*         /\ txmanager(n).type = "ongoing"
\*         /\ n \in t.nodes
\*         /\ msgs' = msgs \ {m}
\*         /\ transactions' = transactions \cup [type: "aborted", nodes: t.nodes]
\*         /\ UNCHANGED routes
\*         /\ UNCHANGED proc

\* all related nodes acknowledged a transaction
\* TxManager == [Nodes -> Transactions]
\* AckManager == [Nodes -> Transactions -> NodeMsgs]
\* CommitTransactions == \A n \in DOMAIN txmanager, t \in txmanager[n]:
\*         /\ ackmanager[n][t] = {"ack_prepare", "ack_commit"}
\*         /\ t.type = "ongoing"
\*         /\ txmanager(n).type = "commited"

CommitTransactions == \A txm \in txmanager, n \in Nodes:
        /\ ackmanager[n][txm[n]] = {"ack_prepare", "ack_commit"}
        /\ txm[n].type = "ongoing"
        /\ txmanager = [txmanager EXCEPT ![n] = [type |-> "commited", txid |-> txm[n].txid]]  

AbortTransactions == \E txm \in txmanager, n \in Nodes, ack \in ackmanager:
        /\ ackmanager[n][txm[n]] = {"ack_prepare", "ack_commit"}
        /\ txm[n].type = "ongoing"
        /\ txmanager = [txmanager EXCEPT ![n] = [type |-> "aborted", txid |-> txm[n].txid]]  

Send(m) == 
        /\ msgs' = msgs \cup {m}
        /\ UNCHANGED proc
        /\ UNCHANGED routes
        /\ UNCHANGED txmanager
        /\ UNCHANGED ackmanager

Next == (\E m \in Msgs, nmsg \in NodeMsgs : Send(nmsg) \/ Send(m) \/ RcvNodeCreate(m) \/ RcvNodeGet(m) \/ RcvNodePut(m) \/ RcvNodeDelete(m) \/ RcvNodeTransactionCommit(m) \/ RcvNodeTransactionStart(m) \/ RcvNodeTransactionCommit(m) \/ CommitTransactions \/ AbortTransactions)
Fairness == WF_vars(Next)
Spec == Init /\ [][Next]_vars /\ Fairness
--------------------------------------------------------------
THEOREM Spec => []TypeInvariant /\ []NodesAlwaysHaveDifferentKeysInvariant /\ []TxTerminationProperty
==============================================================