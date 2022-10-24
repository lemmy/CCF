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

\* Limit max number of simultaneous candidates
\* We made several restrictions to the state space of Raft. However since we
\* made these restrictions, Deadlocks can occur at places that Raft would in
\* real-world deployments handle graciously.
\* One example of this is if a Quorum of nodes becomes Candidate but can not
\* timeout anymore since we constrained the terms. Then, an artificial Deadlock
\* is reached. We solve this below. If TermLimit is set to any number >2, this is
\* not an issue since breadth-first search will make sure that a similar
\* situation is simulated at term==1 which results in a term increase to 2.
CONSTANTS MaxSimultaneousCandidates
ASSUME MaxSimultaneousCandidates \in Nat

\* CCF: Limit how many identical append entries messages each node can send to another
CONSTANTS MessagesLimit
ASSUME MessagesLimit \in Nat

----

BoundStateSpace ==
    \* Limit number of client requests
    /\ clientRequests <= RequestLimit
    /\ \A i \in Servers :
        \* Limit the term of each server to reduce state space
        /\ currentTerm[i] <= TermLimit
        \* Limit number of candidates in our relevant server set
        \* (i.e., simulate that not more than a given limit of servers in each configuration times out)
        /\ Cardinality({ s \in GetServerSetForIndex(i, commitIndex[i]) : state[s] = Candidate}) <= MaxSimultaneousCandidates
        /\ \A j \in Servers :
            \* State limitation: Limit requested votes
            /\ votesRequested[i][j] <= RequestVoteLimit
            /\ Len(messagesSent[i][j]) >= nextIndex[i][j] => messagesSent[i][j][nextIndex[i][j]] <= MessagesLimit

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
