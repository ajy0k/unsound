#!/bin/bash
# Run the smoke test (optionally with a test script) with a watchdog. On a hang it saves the
# stack (sample) to /tmp/unsound-smoke/sample.txt before killing sclang.
dir="$(cd "$(dirname "$0")" && pwd)"
mkdir -p /tmp/unsound-smoke
test="${1:+$(cd "$(dirname "$1")" && pwd)/$(basename "$1")}"
cat > /tmp/unsound-smoke/go.scd <<SCD
${test:+~testFile = "$test";}
"$dir/smoke.scd".load;
SCD
/Applications/SuperCollider.app/Contents/MacOS/sclang /tmp/unsound-smoke/go.scd > /tmp/unsound-smoke/log.txt 2>&1 &
pid=$!
( sleep ${2:-90}; sample $pid 2 -file /tmp/unsound-smoke/sample.txt >/dev/null 2>&1; kill -9 $pid 2>/dev/null; pkill -9 scsynth ) &
wd=$!
wait $pid
kill $wd 2>/dev/null
pkill -9 scsynth 2>/dev/null
grep -E "ERROR|FAILURE|meters:|TEST DONE|unsound:" /tmp/unsound-smoke/log.txt
