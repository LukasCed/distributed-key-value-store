---------------------- MODULE kv_syst ----------------------
EXTENDS TLC
CONSTANT Values, Nodes, Tables, Keys, NULL
VARIABLES msgs, proc, routes, transactions
vars == <<msgs, proc, routes, transactions>>

Msgs == UNION {
    [type: {"node"}, operation: {"get"}, table: Tables, key: Keys, value: Values],
    [type: {"node"}, operation: {"put"}, table: Tables, key: Keys, value: Values],
    [type: {"node"}, operation: {"delete"}, table: Tables, key: Keys, value: Values],
    [type: {"broadcast"}, operation: {"create"}, table: Tables, key: Keys, value: Values],
    [type: {"transaction"}]
}

Routes == [Keys -> Nodes]
Processes == [Nodes -> [Tables -> [(Keys \union NULL) -> (Values \union NULL)]]]

Transactions == UNION {
    [type: {"ongoing"}, nodes: Nodes],
    [type: {"commited"}, nodes: Nodes],
    [type: {"aborted"}, nodes: Nodes]
}

TypeInvariant == 
    /\ proc \in Processes
    /\ msgs \subseteq Msgs
    /\ routes \in Routes

\* if there is two nodes that have same keys in any tables it must be the same node
NodesAlwaysHaveDifferentKeysInvariant == \A p \in Processes, t \in Tables, n1, n2 \in Nodes:
    /\ \A k \in DOMAIN p[n1][t] : \E l \in DOMAIN p[n2][t] : l = k => n1 = n2

ExistOngoingTransactions == \E t \in Transactions:
    /\ t.type = "ongoing"

ExistCommitedTransactions == \E t \in Transactions:
    /\ t.type = "commited"

ExistAbortedTransactions == \E t \in Transactions:
    /\ t.type = "aborted"

TransactionsEventuallyCommitedOrAbortedProperty == ExistOngoingTransactions ~> (ExistCommitedTransactions \/ ExistAbortedTransactions) 

Init ==
    /\ proc \in Processes
    /\ transactions = {}
    /\ msgs = {}
    /\ routes \in Routes

RcvNodeCreate(m) == \A n \in Nodes:
             \E nv \in NULL:
                /\ m.type = "broadcast"
                /\ m.operation = "create"

                /\ proc' = [proc EXCEPT ![n][m.table] = [nv |-> nv]] 
                /\ msgs' = msgs \ {m}
                /\ UNCHANGED routes
                /\ UNCHANGED transactions

RcvNodeGet(m) == \E n \in Nodes:
        /\ m.type = "node"
        /\ m.operation = "get"
        /\ n = routes[m.key]

        /\ msgs' = msgs \ {m}
        /\ UNCHANGED proc
        /\ UNCHANGED routes
        /\ UNCHANGED transactions


RcvNodePut(m) == \E n \in Nodes:
        /\ m.type = "node"
        /\ m.operation = "put"
        /\ n = routes[m.key]

        /\ proc' = [proc EXCEPT ![n][m.table][m.key] = m.value]
        /\ msgs' = msgs \ {m}
        /\ UNCHANGED routes
        /\ UNCHANGED transactions

\* https://stackoverflow.com/questions/47115185/tla-how-to-delete-structure-key-value-pairings
RcvNodeDelete(m) == \E n \in Nodes, nv \in NULL:
        /\ m.type = "node"
        /\ m.operation = "delete"
        /\ n = routes[m.key]

        /\ proc' = [proc EXCEPT ![n][m.table][m.key] = nv]
        \* /\ proc' = [proc EXCEPT ![m.table] = ]

        /\ msgs' = msgs \ {m}
        /\ UNCHANGED routes
        /\ UNCHANGED transactions

RcvNodeTransactionCommit(m) == \E n \in Nodes, t \in transactions:
        /\ m.type = "transaction"
        /\ t.type = "ongoing"
        /\ n \in t.nodes
        /\ msgs' = msgs \ {m}
        /\ transactions' = transactions \cup [type: "aborted", nodes: t.nodes]
        /\ UNCHANGED routes
        /\ UNCHANGED proc

RcvNodeTransactionAbort(m) == \E n \in Nodes, t \in transactions:
        /\ m.type = "transaction"
        /\ t.type = "ongoing"
        /\ n \in t.nodes
        /\ msgs' = msgs \ {m}
        /\ transactions' = transactions \cup [type: "aborted", nodes: t.nodes]
        /\ UNCHANGED routes
        /\ UNCHANGED proc

RcvNodeTransactionStart(m) == \E n \in Nodes:
        /\ m.type = "transaction"
        /\ msgs' = msgs \ {m}
        /\ transactions' = transactions \cup [type |-> "ongoing", nodes |-> {n}]
        /\ UNCHANGED routes
        /\ UNCHANGED proc

RcvNodeTransactionJoin(m) == \E n \in Nodes, t \in transactions:
        /\ m.type = "transaction"
        /\ t.type = "ongoing"
        /\ n \in t.nodes
        /\ msgs' = msgs \ {m}
        /\ transactions' = transactions \cup [type: "aborted", nodes: t.nodes \cup {n}]
        /\ UNCHANGED routes
        /\ UNCHANGED proc


Send(m) == 
        /\ msgs' = msgs \cup {m}
        /\ UNCHANGED proc
        /\ UNCHANGED routes
        /\ UNCHANGED transactions

Next == (\E m \in Msgs : Send(m) \/ RcvNodeCreate(m) \/ RcvNodeGet(m) \/ RcvNodePut(m) \/ RcvNodeDelete(m) \/ RcvNodeTransactionCommit(m) \/ RcvNodeTransactionAbort(m) \/ RcvNodeTransactionStart(m) \/ RcvNodeTransactionJoin(m))
Fairness == WF_vars(Next)
Spec == Init /\ [][Next]_vars /\ Fairness
--------------------------------------------------------------
THEOREM Spec => []TypeInvariant /\ []NodesAlwaysHaveDifferentKeysInvariant /\ []TransactionsEventuallyCommitedOrAbortedProperty
==============================================================