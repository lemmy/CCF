---- MODULE MCabs ----

EXTENDS abs, TLC, SequencesExt, FiniteSetsExt

Symmetry ==
      Permutations(Servers)

CONSTANTS NodeOne, NodeTwo, NodeThree

MCServers == {NodeOne, NodeTwo, NodeThree}
MCTerms == 2..4
MCStartTerm == Min(MCTerms)
MaxExtend == 3

MCTypeOK ==
    \* 4 because of the initial log.
    cLogs \in [Servers -> BoundedSeq(Terms, 4 + MaxExtend)]

MCSeq(S) ==
    BoundedSeq(S, MaxExtend)

\* Limit length of logs to terminate model checking.
MaxLogLengthConstraint ==
    \A i \in Servers :
        Len(cLogs[i]) <= 7
====