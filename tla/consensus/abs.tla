---- MODULE abs ----
\* Abstract specification for a distributed consensus algorithm.
\* Assumes that any node can atomically inspect the state of all other nodes. 

EXTENDS Sequences, SequencesExt, Naturals, FiniteSets, FiniteSetsExt

CONSTANT Servers, Terms, MaxLogLength

\* Commit logs from each node
\* Each log is append-only and the logs will never diverge.
VARIABLE cLogs

TypeOK ==
    /\ cLogs \in [Servers -> 
        UNION {[1..l -> Terms] : l \in 0..MaxLogLength}]

StartTerm == Min(Terms)

InitialLogs == {
    <<>>,
    <<StartTerm, StartTerm>>,
    <<StartTerm, StartTerm, StartTerm, StartTerm>>}
    
Init ==
    cLogs \in [Servers -> InitialLogs]

\* A node i can copy a ledger suffix from another node j.
Copy(i) ==
    \E j \in Servers : 
        /\ Len(cLogs[j]) > Len(cLogs[i])
        /\ \E l \in 1..(Len(cLogs[j]) - Len(cLogs[i])) : 
                cLogs' = [cLogs EXCEPT ![i] = @ \o SubSeq(cLogs[j], Len(@) + 1, Len(@) + l)]

\* A node i with the longest log can extend its log upto length k.
Extend(i, k) ==
    /\ \A j \in Servers : Len(cLogs[j]) \leq Len(cLogs[i])
    /\ \E l \in 0..(k - Len(cLogs[i])) : 
        \E s \in [1..l -> Terms] :
            cLogs' = [cLogs EXCEPT ![i] = @ \o s]

ExtendRefine(i, k) ==
    /\ \A j \in Servers : Len(cLogs[j]) \leq Len(cLogs[i])
    /\ cLogs' \in [Servers -> Seq(Terms)]
    /\ \A j \in Servers: IsPrefix(cLogs[j], cLogs'[j])
    /\ Len(cLogs'[i]) <= Len(cLogs[i]) + k

LEMMA ASSUME NEW i \in Servers, NEW k \in Nat PROVE
    ExtendRefine(i, k) <=> ExtendRefine(i, k)
OMITTED 

ExtendToMax(i) == Extend(i, MaxLogLength)

\* Copy one of the longest logs (from whoever server
\* has it) and extend it further upto length k. This
\* is equivalent to  Copy(i) \cdot Extend(i, k)  ,
\* that TLC cannot handle.
CopyMaxAndExtend(i, k) ==
    /\ \E j \in Servers :
        /\ \A r \in Servers: Len(cLogs[r]) \leq Len(cLogs[j])
        /\ \E l \in 0..(k - Len(cLogs[j])) : 
            \E s \in [1..l -> Terms] :
                cLogs' = [cLogs EXCEPT ![i] = cLogs[j] \o s]

\* The only possible actions are to append log entries.
\* By construction there cannot be any conflicting log entries
\* Log entries are copied if the node's log is not the longest.
Next ==
    \E i \in Servers : 
        \/ Copy(i) 
        \/ ExtendToMax(i)
        \/ CopyMaxAndExtend(i, MaxLogLength)

AbsSpec == Init /\ [][Next]_cLogs

AppendOnlyProp ==
    [][\A i \in Servers : IsPrefix(cLogs[i], cLogs'[i])]_cLogs

NoConflicts ==
    \A i, j \in Servers : 
        \/ IsPrefix(cLogs[i], cLogs[j]) 
        \/ IsPrefix(cLogs[j], cLogs[i])

====