---------------------- MODULE fa_syst ----------------------
EXTENDS TLC
CONSTANT Values, Nodes, tables 
VARIABLES msgs, proc, routes  \* route is not a variable
vars == <<msgs, proc, routes>>

Msgs == UNION {
    [t: {"client"}, b: tables, v: Values],
    [t: {"node"}, b: tables, dst: Nodes, v: Values]
}

Routes == [Nodes -> tables]


NodeMsg(dst, b, v) == [t |-> "node", dst |-> dst, b |-> b, v |-> v]

TypeInvariant == 
    /\ proc \in [Nodes -> [tables -> Values]]
    /\ routes \in Routes
    /\ msgs \subseteq Msgs

Init ==
    /\ \E v \in Values: proc = [ n \in Nodes |-> [ b \in tables |-> v ] ]
    /\ msgs = {}
    /\ routes \in [Nodes -> tables]

RcvN == \E m \in msgs, n \in Nodes:
        /\ m.t = "node"
        /\ m.dst = n
        /\ proc' = [proc EXCEPT ![n][m.b] = m.v] 
        /\ msgs' = msgs \ {m}
        /\ UNCHANGED routes

RcvC == \E m \in msgs, n \in Nodes: 
        /\ m.t = "client"
        /\ m.b = routes[n]
        /\ proc' = [proc EXCEPT ![n][m.b] = m.v] 
        /\ msgs' = msgs \ {m}
        /\ UNCHANGED routes

RcvCRoute == \E m \in msgs, n \in Nodes: 
        /\ m.t = "client"
        /\ m.b = routes[n]
        /\ msgs' = (msgs \ {m}) \cup {NodeMsg(CHOOSE node \in Nodes : node /= n, m.b, m.v)}
        /\ UNCHANGED proc
        /\ UNCHANGED routes

ClientSend(m) == 
        /\ msgs' = msgs \cup {m}
        /\ UNCHANGED proc
        /\ UNCHANGED routes

Next == (\E m \in Msgs : ClientSend(m)) \/ RcvCRoute \/ RcvC \/ RcvN
\* Fairness == WF_vars(Next)
Spec == Init /\ [][Next]_vars \* /\ Fairness
--------------------------------------------------------------
THEOREM Spec => []TypeInvariant
==============================================================