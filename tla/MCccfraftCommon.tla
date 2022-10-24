---------- MODULE MCccfraftCommon ----------
EXTENDS ccfraft

\* CCF: Limit on vote requests to be sent to each other node per election
\* Generally, this should be set to one
\* If zero, then a candidate will not receive any votes (except from itself)
CONSTANTS RequestVoteLimit
ASSUME RequestVoteLimit \in Nat

----

BoundStateSpace ==
    \A i \in Servers :
        /\ \A j \in Servers :
            \* State limitation: Limit requested votes
            /\ votesRequested[i][j] <= RequestVoteLimit
    

==================================
