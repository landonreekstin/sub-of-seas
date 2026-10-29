# Shortcuts. `./play` runs the game (see its header for modes).
.PHONY: play test walkthrough

play:
	./play

# Unit tests (exit 1 on failure), then the whole training patrol played by script.
test:
	godot --headless --path . -s tests/run_tests.gd
	godot --headless --path . -s tests/tutorial_walkthrough.gd

walkthrough:
	godot --headless --path . -s tests/tutorial_walkthrough.gd
