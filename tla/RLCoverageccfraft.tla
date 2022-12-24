---------- MODULE RLCoverageccfraft ----------
EXTENDS SIMccfraft, TLC, Integers, CSV, TLCExt, IOUtils, SequencesExt

CSVTemplateString(columns, delim) ==
    \* Create the Java format string for the given num of columns and delim (here #): %$1s#%$2s#%$3s#...
    \* We cheat a little by using the fact that TLC normalizes (orders) the set 1..columns.
    FoldSet(LAMBDA a, b: b \o (IF b = "" THEN "%" ELSE delim \o "%") \o ToString(a) \o "$s", "", 1..columns)

------------------------------------------------------------------------------

conf == 
    IOEnv.conf

View ==
    CASE   conf = "reconfigurationVars" -> <<reconfigurationVars>>
        [] conf = "messageVars" -> messageVars
        [] conf = "serverVars" -> serverVars
        [] conf = "candidateVars" -> candidateVars
        [] conf = "leaderVars" -> leaderVars
        [] conf = "logVars" -> logVars
        [] conf = "state" -> state
        [] conf = "messages" -> messages
        [] conf = "state,messages" -> <<state, messages>>
        [] conf = "log" -> log
        [] conf = "state,log" -> <<state, log>>
        [] conf = "Rangestate" -> Range(state)
        [] conf = "state,committedLog" -> <<state, committedLog>>
        [] conf = "currentTerm,state" -> <<currentTerm, state>>
        [] conf = "state,votedFor" -> <<state, votedFor>>
        [] conf = "serverVars,configurations" -> serverVars \o <<configurations>>
        [] conf = "configurations" -> configurations
        [] conf = "currentTerm" -> currentTerm
        [] conf = "vars" -> vars
        [] OTHER -> <<>>

------------------------------------------------------------------------------

CSVFile == "RLCoverageccfraft_S" \o ToString(Cardinality(Servers)) \o ".csv"

CSVColumnHeaders ==
    "Spec#Mode#View#Depth#Id#reconfigurationCount#committedLog#clientRequests#commitsNotified11#commitsNotified12#currentTerm#state#node"

ASSUME
    CSVRecords(CSVFile) = 0 => 
        CSVWrite(CSVColumnHeaders, <<>>, CSVFile)

VariableStatisticsStateConstraint ==
    \A srv \in Servers :
        LET values == << "Spec", TLCGet("config").sched, conf, TLCGet("level"), TLCGet("stats").behavior.id, 
            reconfigurationCount, committedLog.index, clientRequests, 
            commitsNotified[srv][1], commitsNotified[srv][2], 
            currentTerm[srv], state[srv], srv>>
        IN CSVWrite(CSVTemplateString(Len(values), "#"), values, CSVFile)

------------------------------------------------------------------------------

Actions ==
    \* A sequence of all the action names in the spec.
    SetToSeq(DOMAIN TLCGet("stats").behavior.actions)

CSVActionFile == "RLCoverageccfraft_actions.csv"

ASSUME
    \* Write the header row if the file is empty.
    CSVRecords(CSVActionFile) = 0 =>
        CSVWrite("Mode#View#Trials#Id" \o FoldSeq(LAMBDA a, b: b \o "#" \o a, "", Actions), <<>>, CSVActionFile)

ActionStatisticsStateConstraint ==
    LET values == << TLCGet("config").sched, conf>> 
            \o <<TLCGet("stats").trials, TLCGet("stats").behavior.id>>
            \o [ i \in 1..Len(Actions) |-> TLCGet("stats").behavior.actions[Actions[i]] ]
    IN CSVWrite(CSVTemplateString(Len(values), "#"), values, CSVActionFile)

------------------------------------------------------------------------------

StatisticsStateConstraint ==
    \* Cannot use two or more (state) constraints with TLCDefer because only one would be evalauted.  
    \* Thus, we use a single, outter constraint with TLCDefer that wraps both stats formulas.
    (TLCGet("level") > TLCGet("config").depth) =>
        TLCDefer(
            /\ VariableStatisticsStateConstraint
            /\ ActionStatisticsStateConstraint
        )   

------------------------------------------------------------------------------

PlotStatistics ==
    \* Have TLC execute the R script on the generated CSV file.
    LET proc == IOExec(<<
            \* Finds R on the current system (known to work on macOS and Linux).
            "/usr/bin/env", "Rscript",
            "RLCoverageccfraft.R", CSVFile, CSVActionFile>>)
    IN \/ proc.exitValue = 0
       \/ PrintT(proc) \* Print stdout and stderr if R script fails.

=============================================================================
