#!/bin/bash

set -e

JSON=traces/bad_network.ndjson java -XX:+UseParallelGC -Dtlc2.tool.impl.Tool.cdot=true -cp '/Applications/TLA+ Toolbox.app/Contents/Eclipse/tla2tools.jar' tlc2.TLC -note Traceccfraft.tla
JSON=traces/replicate.ndjson java -XX:+UseParallelGC -Dtlc2.tool.impl.Tool.cdot=true -cp '/Applications/TLA+ Toolbox.app/Contents/Eclipse/tla2tools.jar' tlc2.TLC -note Traceccfraft.tla
JSON=traces/election.ndjson java -XX:+UseParallelGC -Dtlc2.tool.impl.Tool.cdot=true -cp '/Applications/TLA+ Toolbox.app/Contents/Eclipse/tla2tools.jar' tlc2.TLC -note Traceccfraft.tla
JSON=traces/check_quorum.ndjson java -XX:+UseParallelGC -Dtlc2.tool.impl.Tool.cdot=true -cp '/Applications/TLA+ Toolbox.app/Contents/Eclipse/tla2tools.jar' tlc2.TLC -note Traceccfraft.tla
JSON=traces/reconnect.ndjson java -XX:+UseParallelGC -Dtlc2.tool.impl.Tool.cdot=true -cp '/Applications/TLA+ Toolbox.app/Contents/Eclipse/tla2tools.jar' tlc2.TLC -note Traceccfraft.tla
JSON=traces/reconnect_node.ndjson java -XX:+UseParallelGC -Dtlc2.tool.impl.Tool.cdot=true -cp '/Applications/TLA+ Toolbox.app/Contents/Eclipse/tla2tools.jar' tlc2.TLC -note Traceccfraft.tla

JSON=traces/fancy_election.1.ndjson java -XX:+UseParallelGC -Dtlc2.tool.impl.Tool.cdot=true -cp '/Applications/TLA+ Toolbox.app/Contents/Eclipse/tla2tools.jar' tlc2.TLC -note Traceccfraft.tla
JSON=traces/suffix_collision.1.ndjson java -XX:+UseParallelGC -Dtlc2.tool.impl.Tool.cdot=true -cp '/Applications/TLA+ Toolbox.app/Contents/Eclipse/tla2tools.jar' tlc2.TLC -note Traceccfraft.tla

# JSON=traces/suffix_collision.2.ndjson java -XX:+UseParallelGC -Dtlc2.tool.impl.Tool.cdot=true -cp '/Applications/TLA+ Toolbox.app/Contents/Eclipse/tla2tools.jar' tlc2.TLC -note Traceccfraft.tla
# JSON=traces/fancy_election.2.ndjson java -XX:+UseParallelGC -Dtlc2.tool.impl.Tool.cdot=true -cp '/Applications/TLA+ Toolbox.app/Contents/Eclipse/tla2tools.jar' tlc2.TLC -note Traceccfraft.tla
