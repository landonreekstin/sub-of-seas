# Shortcuts. `./play` runs the game (see its header for modes).
.PHONY: play test walkthrough

play:
	./play

COURSES := full helm scope torpedo sonar damage engine attack control party

# Unit tests (exit 1 on failure), then every training course played by script.
test:
	godot --headless --path . -s tests/run_tests.gd
	$(MAKE) walkthrough

walkthrough:
	set -e; for c in $(COURSES); do godot --headless --path . -s tests/tutorial_walkthrough.gd -- $$c; done
	godot --headless --path . -s tests/pa_walkthrough.gd
	set -e; for s in gato s_boat typhoon; do godot --headless --path . -s tests/all_hands_walkthrough.gd -- $$( [ $$s = typhoon ] && echo cw_convoy || echo convoy ) $$s; done
	godot --headless --path . -s tests/duel_walkthrough.gd
	godot --headless --path . -s tests/typhoon_walkthrough.gd
	set -e; for s in typhoon gato s_boat narwhal; do godot --headless --path . -s tests/party_walkthrough.gd -- $$s; done
	godot --headless --path . -s tests/door_walk.gd -- typhoon
	set -e; for h in pa ballast planesman dive; do godot --headless --path . -s tests/breach_hatch.gd -- typhoon $$h; done
	godot --headless --path . -s tests/breach_hatch.gd -- gato dive
	set -e; for s in gato s_boat typhoon; do godot --headless --path . -s tests/muffle_check.gd -- $$s; done
	set -e; for s in gato s_boat narwhal typhoon; do godot --headless --path . -s tests/pastime_walkthrough.gd -- $$s; done
	set -e; for c in scope torpedo attack; do godot --headless --path . -s tests/tutorial_walkthrough.gd -- $$c realistic; done
