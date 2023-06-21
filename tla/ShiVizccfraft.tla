------------------- MODULE ShiVizccfraft -------------------
EXTENDS MCccfraft, Json, TLC, TLCExt

VectorClockMerge(i, r, l) == 
    [ m \in Servers |-> IF m = i THEN l[m] + 1 ELSE max(r[m], l[m]) ]

VARIABLE clock

ShiVizInit ==
    /\ InitReconfigurationVars
    /\ InitMessagesVars
    /\ InitServerVars
    /\ InitCandidateVars
    /\ InitLeaderVars
    /\ InitLogVars
    /\ clock = [ s \in Servers |-> [ t \in Servers |-> 0 ] ]

ShiVizNext ==
    \/ \E i, j \in Servers : 
        /\ clock' = [ clock EXCEPT ![i][i] = @ + 1 ]
        /\ \/ RequestVote(i, j)
           \/ Timeout(i)
           \/ BecomeLeader(i)
           \/ ClientRequest(i)
           \/ SignCommittableMessages(i)
           \/ ChangeConfiguration(i)
           \/ NotifyCommit(i,j)
           \/ AdvanceCommitIndex(i)
           \/ AppendEntries(i, j)
           \/ CheckQuorum(i)
    \/ \E m \in Messages:
        /\ clock' = [ clock EXCEPT ![m.dest] = VectorClockMerge(m.dest, m.vc, @) ]
        /\ Receive(m)

ShiVizWithMessage(m, msgs) ==
    msgs \union {m @@ [vc |-> clock'[m.source]]}

ShiVizView == <<
    reconfigurationVars, 
    commitsNotified,
    serverVars, 
    candidateVars, 
    leaderVars, 
    logVars,
    \* Remove vc field from messages and exclude clock variable.
    { [ k \in (DOMAIN m \ {"vc"}) |-> m[k] ] :m \in Messages}
>>

ShiVizvars == <<
    reconfigurationVars, 
    messageVars, 
    serverVars, 
    candidateVars, 
    leaderVars, 
    logVars,
    clock
>>

-----------------------------------------------------

host ==
    LET lvl == TLCGet("level")
    IN CHOOSE n \in Servers:
            Trace[lvl].clock[n] # Trace[lvl-1].clock[n]

ShiVizAlias ==
    [
        Host |-> host,
        Clock |-> ToJsonObject(clock[host]),
        messages |-> messages,
        currentTerm |-> currentTerm,
        state |-> state,
        log |-> log,
        commitIndex |-> commitIndex,
        nextIndex |-> nextIndex,
        matchIndex |-> matchIndex
    ]

=====================================================


1. Change EXTENDS above to extend the MCccfraft module you wish to debug.
2. Append the following to the end of the correspondig config:

CONSTANTS
    WithMessage <- ShiVizWithMessage
    vars <- ShiVizvars
    Init <- ShiVizInit
    Next <- ShiVizNext

ALIAS 
    ShiVizAlias

3. Run TLC with `-Dtlc2.value.Values.width=9999` to prevent line breaks in values.
4. Copy&paste TLC's output into http://bestchai.bitbucket.org/shiviz/.  Paste the following regular expression into the "Log parsing regular expression:" field:

(?<event>[0-9]+: <\w*) .*>\n\/\\ Host = (?<host>.*)\n\/\\ Clock = "(?<clock>.*)"\n\/\\ messages = (?<messages>.*)\n\/\\ currentTerm = (?<currentTerm>.*)\n\/\\ state = (?<state>.*)\n\/\\ log = (?<log>.*)\n\/\\ commitIndex = (?<commitIndex>.*)\n\/\\ nextIndex = (?<nextIndex>.*)\n\/\\ matchIndex = (?<matchIndex>.*)
