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

----

BoundStateSpace ==
    \A i \in Servers :
        \* Limit the term of each server to reduce state space
        /\ currentTerm[i] <= TermLimit
        /\ \A j \in Servers :
            \* State limitation: Limit requested votes
            /\ votesRequested[i][j] <= RequestVoteLimit
    
==================================
