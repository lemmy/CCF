---------- MODULE MCccfraftCommon ----------
EXTENDS ccfraft

\* CCF: Limit on vote requests to be sent to each other node per election
\* Generally, this should be set to one
\* If zero, then a candidate will not receive any votes (except from itself)
CONSTANTS RequestVoteLimit
ASSUME RequestVoteLimit \in Nat

\* Limit on terms
\* By default, all servers start as followers in term one
\* So this should therefore be at least two
CONSTANTS TermLimit
ASSUME TermLimit \in Nat \ {0}

\* Limit on client requests
CONSTANTS RequestLimit
ASSUME RequestLimit \in Nat

----

BoundStateSpace ==
    \* Limit number of client requests
    /\ clientRequests <= RequestLimit
    /\ \A i \in Servers :
        \* Limit the term of each server to reduce state space
        /\ currentTerm[i] <= TermLimit
        /\ \A j \in Servers :
            \* State limitation: Limit requested votes
            /\ votesRequested[i][j] <= RequestVoteLimit

----

\* Returns true if server i has committed value v, false otherwise
IsCommittedByServer(v,i) ==
    IF commitIndex[i]  = 0
    THEN FALSE
    ELSE \E k \in 1..commitIndex[i] :
        /\ log[i][k].contentType = TypeEntry
        /\ log[i][k].value = v

\* This invariant shows that at least one value is committed on at least one server
DebugInvAnyCommitted ==
    \lnot (\E v \in 1..RequestLimit : \E i \in Servers : IsCommittedByServer(v,i))

\* This invariant shows that all values are committed on at least one server each
DebugInvAllCommitted ==
    \lnot (\A v \in 1..RequestLimit : \E i \in Servers : IsCommittedByServer(v,i))

==================================
