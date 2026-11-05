# Notes

Where things stand, in plain English. The newest entry goes at the top. Update it at every pause.
Other docs: `roadmap.md` is the to-do list, `style.md` how it looks and feels, `design.md` the
game's design, `credits.md` where every sound came from.

## 2026-11-04 (late night): three new items, branch `blaney/typhoon-bridge`, draft PR #36

Blaney may cut a session off at any point: commit, push and update this after every step.
His calls (asked once at the start): Typhoon lit like the film (cold blue-white, deep red at battle
stations / all hands); command bay with two seats side by side at aircraft yokes (helmsman,
planesman), skipper behind at the periscope; Gato packed with pipes, valves, gauges and cables like
WWII photos; the all-hands crowd see-through, never blocking.
- [built, tests pass] **All hands on deck** (any boat): every post manned, 3 sailors standing in each
  room (`SubInterior._sync_crowd`), damage parties on standby, and the crew work the objective
  themselves (`BotCrew.all_hands`, `_work_objective`): sink the nearest ship it wants, then the next;
  on a "survive" patrol, go deep and quiet while hunted. "Stand down" sends them all off.
  `tests/all_hands_walkthrough.gd` passes on Gato, S-boat, Typhoon.
- [built, parses, NOT looked at yet] **Typhoon command bay** (`TyphoonLayout._command_bay`,
  `stations/yoke_station.gd`): helmsman (starboard) and planesman (port) seated at yokes facing the
  bow under a gauge bank; planesman holds W to push down / S to pull up, helmsman A/D or mouse
  rudder, C centre, W/S engine order; periscope dais with brass rail behind them, skipper's chair
  to port, sonar port, fire control (TDC) starboard, cable trays overhead. **Lights:** Typhoon
  blue-white, deep red while all hands (`full_crew`) is on (`SubInterior._process`).
- 2026-11-05: two more items, his calls: **emergency breaching = crash surface** (an emergency blow
  so hard the bow leaps out and slams down); **hologram: Typhoon only, blue glow**.
- [built, looked at] bots sit at the yokes; **hologram** (`stations/holo_station.gd`, the skipper's
  chair to port of the scope; H toggles `crew.holo`, everyone sees it): heading-up, sea floor grid,
  ships heard or seen, torpedoes (theirs red). Screenshot `tools/typhoon_looks.gd -- <dir> bay calm`.
- [built, unit-tested, not seen] **crash surface** (`SubState.breach`): an emergency blow (X twice,
  or "crash surface" on the PA) bringing her up through the surface at 1.5 m/s or more: bow up to
  28°, thrown up to 6 m, slammed down, rocks to rest over 7 s; the "breach" event shakes everyone
  twice, flickers the lights, splashes. Outside, `ExteriorWorld._place_own` pitches and lifts her.
- [next] look at a breach from the outside cameras, then the detail pass (Typhoon, Gato), style log, make test, Blaney plays.
- **Earlier stop.** Next was: open the screenshots already taken in
  `screenshots/bay/calm/` and `screenshots/bay/full/` (`tools/typhoon_looks.gd -- <dir> bay [calm]`),
  fix what looks wrong, run `make test` (unit tests passed after all hands; walkthroughs not rerun
  since the bay changed), then Typhoon detail (Red October), Gato detail (packed pipes, valves,
  gauges, cables), log his four calls in `docs/style.md`, update CLAUDE.md controls, Blaney plays,
  tick the three items, PR #36 ready, then `vibenote --collect-usage`.

## 2026-11-04 (night): everything of Blaney's is ready for Lando

Blaney played the waiting changes on a Gato: "the game works". PRs #28-#35 are all marked ready. They stack in that order, #31 already was. #29 (crew training together) hasn't been tried by two real players yet; the PR says so. Nothing of Blaney's is in progress.

## 2026-11-04 (evening): the Typhoon is finished; PR #35 ready (Blaney: "yes mark it as done")

Blaney: focus on a few tasks and finish each, so Lando isn't left waiting on half-done work.
- Choir: it played, but at -13 dB it was lost under the boat. Now as loud as the menu music. It still stops while the band plays.
- Hull, fin and deck are black rubber (Blaney: "as real as we can get").
- Frame rate on his RTX 3060: 60 fps in every room on both boats. Worst room to draw: Typhoon 3.9 ms, Gato 2.6 ms.
- `make test`: all clean.
- **Next:** Blaney plays once more and listens for the choir. Then `gh pr ready 35`. After that, his play of #32, #33 and #34, so they can come out of draft too. Nothing new before those.

## 2026-11-04 (later): Blaney has played the Typhoon, paused here at his word

**Blaney's verdict:** "wow this is great". The floor flicker is gone. He asked to save here and pick it up later; next session, start with "Next" below.

**Fixed this session (all on PR #35):**
- Damage parties walk through doors and up the ladder on every boat, opening shut doors and shutting them behind them (`SubInterior.route`, `BotCrew._walk_team`; `tests/party_walkthrough.gd`).
- Blocked doors: the dartboard was in front of the rec room's side door (door moved to z -7.5), bunks across the crew's quarters' doors, the port turbine across its door. `tests/door_walk.gd` walks a player through every door both ways. Missile tubes, turbines and the rudder ram are now solid.
- Floor flicker: the command bay's and navigation room's floor was level with the passage's ceiling. They're now 6 cm higher.
- Long rooms have a lamp every 14 m or so. The mess menu is in Russian. Docs updated: `style.md`, `credits.md`, `CLAUDE.md`, `Makefile`.

**Next (Blaney's calls, not started):**
1. **The choir: he doesn't hear it.** "i dont know how to make the choir happen, no music like that that i hear". It's meant to start by itself on a Typhoon (`Game` track "typhoon"), with nothing to trigger it. Cause not checked. Suspects: it's very quiet (-13 dB, and his Music slider is at 0.56), and it falls silent while the band plays. Find out, make it audible, have him judge it by ear.
2. **Her outside: "definitely as real as we can get for the typhoon".** He picked this when asked about the deck: a real Typhoon has a black rubber-coated hull, ours has the WWII boats' tan wood deck. Change it, and check the rest of `ShipModels.own_boat`'s Typhoon against pictures of the real boat while there. "As real as we can get" is logged in `style.md`, so apply it to other Typhoon choices too.

**Still open on the list:**
- Frame rate against a Gato: not measured on the Gato yet. On Blaney's RTX 3060 at 1280x720, all hands and the band aboard: all 19 rooms at the 60 fps cap, under 4 ms CPU and under 4 ms GPU to draw each. His game felt fine in play. One late reading of script time was 19 ms, taken while a lighting error (since fixed) was being printed thousands of times; measure it again.
- `make test`: last full run was before the latest fixes. 561 unit tests passed and all ten training courses finished, then it stopped at the enemy-sub test. That test failed 2 of 5 runs because it re-gave the order every 15 s, restarting the attack, and allowed only 500 s. It now gives the order once and allows 1200 s, but hasn't been rerun since, so it needs one clean run. A hunt can be long if she runs, which may be worth a look for balance.
- PR #35 stays a draft until the choir and her outside are done and `make test` is clean.
- Blaney still has to play #32, #33 and #34 so Lando can take them out of draft. #33 (PA, bots) has now been in his hands only as part of the Typhoon, if he used it.
- `vibenote --collect-usage` runs when the whole list is done, not before.

**Ask first:** Blaney wants to be asked before each check that uses his graphics card or screen. Headless and `xvfb-run` checks need no asking, though `xvfb-run` is very slow (about 1 frame a second).

**Looks noticed, not changed:** sailors stand still and you walk through them, and name tags are very large up close. Worth asking him about.

## 2026-11-04: Blaney's last open items

**Done, in draft PRs waiting for Blaney to play them:**
- #32: no music at sea; menu music stays; jukebox stops while instruments play; sprint 2.1×.
- #33: PA microphone you type orders into; J hands your station to a bot.
- #34: enemy sub fight (menu, or "enemy sub" on the PA) and the map of only what you've seen.

**In progress, draft PR on branch `blaney/typhoon`:** the Typhoon is built and its tests pass, but nobody has looked at it yet, so its two to-do items stay unticked. Blaney's choices: real full size (175 m) with a faster sprint; Cold War enemies; music and sounds in the mood of The Hunt for Red October. That film's theme is copyrighted, so ours is an original men's choir piece.
- Checked by script only: 19 rooms, all hands, band, damage parties fix damage, sinking a ship, enemy sub fight.
- **Next:** take screenshots of every room and look at them (doors, cross passages, Russian signs, notebooks, her outside); compare frame rate with a Gato (Blaney: must not lag); then Blaney plays it; update `docs/style.md`, `docs/credits.md`, `CLAUDE.md`, `Makefile` (add `tests/typhoon_walkthrough.gd`), tick the items and mark the PR ready.
- Known rough edge (fixed since, see above): damage parties walk in a straight line, through walls.
- Try it: `./play host cw_convoy typhoon`, E at the PA on the command bay's after bulkhead, type "all hands".

**Test results, 2026-11-04 (headless, by script):**
- Unit tests, on `blaney/typhoon`: 559 passed, 0 failed.
- `tests/typhoon_walkthrough.gd`: passed. All hands, the band, parties fixed a leak, a fire and a broken helm, a ship sunk.
- `tests/duel_walkthrough.gd`: passed on the Gato and the Typhoon.
- `tests/pa_walkthrough.gd`: passed at Arcade and Realistic, on `blaney/crew-pa`; not rerun since.
- **Not run:** the training walkthroughs in full (`make walkthrough`). Only the helm and torpedo courses were started, on `blaney/crew-pa`, and neither result was confirmed. The interior was reworked for the Typhoon after that, so run `make test` before anything leaves draft.

**The Typhoon's layout:** public sources give five pressure hulls: two long ones side by side, a
smaller command hull above them, one for torpedoes forward and one for steering aft, with the
missile tubes between the main hulls. No exact room-by-room plan is published, so the rooms inside
the hulls are our best fit: 19 compartments, 160 crew. Source:
https://en.wikipedia.org/wiki/Typhoon-class_submarine

**PRs stack:** #27 to #34 sit on top of each other and merge in that order.
