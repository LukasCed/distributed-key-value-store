---------------------- MODULE kv_syst ----------------------
EXTENDS TLC
CONSTANT Nodes
VARIABLES node_states
vars == <<node_states>>

States == UNION {
    [name: {"q"}], \* initial 
    [name: {"w"}], \* waiting 
    [name: {"a"}], \* aborte
    [name: {"p"}], \* prepare
    [name: {"c"}] \* commit
}
NodeStates == [Nodes -> States]

TypeInvariant == 
    /\ node_states \in NodeStates

TxTerminationProperty == \A n \in Nodes: node_states[n].name = "q" ~> node_states[n].name \in {"c", "a"}

NonblockingProperty == \A n1, n2 \in Nodes: 
        /\ (n1 /= n2 /\ node_states[n1].name = "q" => (node_states[n2].name = "q" \/ node_states[n2].name = "w" \/ node_states[n2].name = "a"))
        /\ (n1 /= n2 /\ node_states[n1].name = "w" => (node_states[n2].name = "w" \/ node_states[n2].name = "q" \/ node_states[n2].name = "a" \/ node_states[n2].name = "p"))
        /\ (n1 /= n2 /\ node_states[n1].name = "a" => (node_states[n2].name = "a" \/ node_states[n2].name = "q" \/ node_states[n2].name = "w"))
        /\ (n1 /= n2 /\ node_states[n1].name = "p" => (node_states[n2].name = "p" \/ node_states[n2].name = "w" \/ node_states[n2].name = "c"))
        /\ (n1 /= n2 /\ node_states[n1].name = "c" => (node_states[n2].name = "c" \/ node_states[n2].name = "p"))

Init ==
    /\ node_states \in NodeStates /\ (\A n \in Nodes: node_states[n].name = "q")

\*--------------------------------- TRANSACTIONS \*---------------------------------*\
InitTransaction == \E n \in Nodes, ns \in States:
        /\ node_states[n].name = "q"
        /\ (ns.name = "w" \/ ns.name = "a")
        /\ node_states' = [node_states EXCEPT ![n] = ns]

PrepareTransaction == \E n \in Nodes, ns \in States:
        /\ node_states[n].name = "w"
        /\ (ns.name = "p" \/ ns.name = "a")
        /\ node_states' = [node_states EXCEPT ![n] = ns]

CommitTransaction == \E n \in Nodes, ns \in States:
        /\ node_states[n].name = "p"
        /\ ns.name = "c"
        /\ node_states' = [node_states EXCEPT ![n] = ns]
 
AbortTransaction == \E n \in Nodes, ns \in States:
        /\ (node_states[n].name = "q" \/ node_states[n].name = "w")
        /\ ns.name = "a"
        /\ node_states' = [node_states EXCEPT ![n] = ns]

Next == (InitTransaction \/ PrepareTransaction \/ CommitTransaction \/ AbortTransaction)
Fairness == WF_vars(Next)
Spec == Init /\ [][Next]_vars /\ Fairness
--------------------------------------------------------------
THEOREM Spec => []TypeInvariant /\ []NonblockingProperty /\ []TxTerminationProperty
==============================================================