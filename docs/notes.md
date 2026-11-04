# Notes

Where things stand, in plain English. The newest entry goes at the top. Update it at every pause.
Other docs: `roadmap.md` is the to-do list, `style.md` how it looks and feels, `design.md` the
game's design, `credits.md` where every sound came from.

## 2026-11-04: Blaney's last open items

**Done, in draft PRs waiting for Blaney to play them:**
- #32: no music at sea; menu music stays; jukebox stops while instruments play; sprint 2.1×.
- #33: PA microphone you type orders into; J hands your station to a bot.
- #34: enemy sub fight (menu, or "enemy sub" on the PA) and the map of only what you've seen.

**In progress, draft PR on branch `blaney/typhoon`:** the Typhoon is built and its tests pass, but nobody has looked at it yet, so its two to-do items stay unticked. Blaney's choices: real full size (175 m) with a faster sprint; Cold War enemies; music and sounds in the mood of The Hunt for Red October. That film's theme is copyrighted, so ours is an original men's choir piece.
- Checked by script only: 19 rooms, all hands, band, damage parties fix damage, sinking a ship, enemy sub fight.
- **Next:** take screenshots of every room and look at them (doors, cross passages, Russian signs, notebooks, her outside); compare frame rate with a Gato (Blaney: must not lag); then Blaney plays it; update `docs/style.md`, `docs/credits.md`, `CLAUDE.md`, `Makefile` (add `tests/typhoon_walkthrough.gd`), tick the items and mark the PR ready.
- Known rough edge: damage parties walk in a straight line, through walls.
- Try it: `./play host cw_convoy typhoon`, E at the PA on the command bay's after bulkhead, type "all hands".

**The Typhoon's layout:** public sources give five pressure hulls: two long ones side by side, a
smaller command hull above them, one for torpedoes forward and one for steering aft, with the
missile tubes between the main hulls. No exact room-by-room plan is published, so the rooms inside
the hulls are our best fit: 19 compartments, 160 crew. Source:
https://en.wikipedia.org/wiki/Typhoon-class_submarine

**PRs stack:** #27 to #34 sit on top of each other and merge in that order.
