# Shortcuts. `./play` runs the game (see its header for modes).
.PHONY: play test walkthrough

play:
	./play

COURSES := full helm scope torpedo sonar damage engine attack control party

# Unit tests (exit 1 on failure), then every training course played by script.
test:
	godot --headless --path . -s tests/run_tests.gd
	$(MAKE) walkthrough

walkthrough: # all of them side by side, one per core (JOBS=1 for one at a time); logs in tests/logs/
	tests/walkthroughs.sh
