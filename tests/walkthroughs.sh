#!/bin/sh
# Every walkthrough (see "Test" in CLAUDE.md), several at once: one per core, up to $JOBS.
# Each gets its own port (TEST_PORT) and 20 minutes at most. Each one's output goes to tests/logs/<name>.log; failures are listed at the end. Exit 1 on any.
cd "$(dirname "$0")/.." || exit 1
JOBS=${JOBS:-$(nproc)}
mkdir -p tests/logs
rm -f tests/logs/*.log
{
	for c in full helm scope torpedo sonar damage engine attack control party; do echo "tutorial_walkthrough.gd $c"; done
	for c in scope torpedo attack; do echo "tutorial_walkthrough.gd $c realistic"; done
	echo "pa_walkthrough.gd"
	echo "all_hands_walkthrough.gd convoy gato"
	echo "all_hands_walkthrough.gd convoy s_boat"
	echo "all_hands_walkthrough.gd cw_convoy typhoon"
	echo "duel_walkthrough.gd"
	echo "typhoon_walkthrough.gd"
	for s in typhoon gato s_boat narwhal; do echo "party_walkthrough.gd $s"; done
	echo "door_walk.gd typhoon"
	for h in pa ballast planesman dive; do echo "breach_hatch.gd typhoon $h"; done
	echo "breach_hatch.gd gato dive"
	for s in gato typhoon titan; do echo "cave_crew.gd $s pa"; done
	echo "cave_crew.gd gato all_hands"
	for s in gato typhoon; do echo "god_out.gd $s"; done
	for s in gato s_boat typhoon; do echo "captain_walkthrough.gd $s"; done
	for s in gato typhoon; do echo "swim_walk.gd $s"; done
	for s in gato s_boat typhoon; do echo "muffle_check.gd $s"; done
	for s in gato s_boat narwhal typhoon; do echo "pastime_walkthrough.gd $s"; done
} | awk '{ print 7100 + NR, $0 }' | xargs -P "$JOBS" -I{} sh -c '
	set -- {}
	port=$1; shift
	log="tests/logs/$(echo "$*" | tr " " "_").log"
	# Its own port (no two can clash), and never more than 20 minutes: a stuck one fails.
	if TEST_PORT=$port timeout 1200 godot --headless --path . -s "tests/$1" -- $(echo "$*" | cut -s -d" " -f2-) >"$log" 2>&1; then echo "ok    $*"; else echo "FAIL  $*  (see $log)"; touch tests/logs/.failed; fi'
if [ -e tests/logs/.failed ]; then rm -f tests/logs/.failed; exit 1; fi
