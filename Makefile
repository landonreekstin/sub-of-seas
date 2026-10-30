# Shortcuts. `./play` runs the game (see its header for modes).
.PHONY: play test walkthrough

play:
	./play

COURSES := full helm scope torpedo sonar damage engine

# Unit tests (exit 1 on failure), then every training course played by script.
test:
	godot --headless --path . -s tests/run_tests.gd
	$(MAKE) walkthrough

walkthrough:
	set -e; for c in $(COURSES); do godot --headless --path . -s tests/tutorial_walkthrough.gd -- $$c; done
