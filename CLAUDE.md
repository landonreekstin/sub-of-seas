*Created by `gd new`. The rules for every game project are in `../CLAUDE.md`.*

## The game

**Sub of Seas** — "Sea of Thieves in a WWII submarine". First-person 3D co-op PvE for 3–8
friends on a LAN. A US submarine crew in the Pacific hunts AI-controlled Imperial Japanese
Navy surface ships (freighters, carriers, battleships, cruisers, destroyers, escorts,
sub-chasers) and survives being hunted. Players never leave the sub: they walk between
compartments and decks and use stations (helm, dive, periscope, sonar, TDC, torpedo tubes,
engine, ballast, air), and fix leaks, fires and broken systems with tools while opening and
closing watertight doors. Three sub sizes (S-boat, Gato, Narwhal) for different crew sizes.
Sessions are patrol missions; an open-sea sandbox comes later.

Look: Peak-like low-poly flat colours now, textures toward Sea of Thieves later.

- `docs/design.md` — full game design (loop, subs, stations, damage, enemies, TDC)
- `docs/ships.md` — historical ship data and the game values derived from it
- `docs/style.md` — look and feel + direction log (read before any visible change)
- `docs/roadmap.md` — milestones, ticked as they land
- `docs/capabilities.md` — what Claude does alone vs what needs lando

## How it is built

Godot **4.7.2**, GDScript, Jolt 3D physics. Repo: github.com/landonreekstin/sub-of-seas
(private; lando's, Blaney works on it too — see "Working together" below).

### Architecture
- **Two spaces.** The sub interior is a static first-person level that never moves. The ocean
  world is a separate simulation (`autoload/sim.gd` + `sim/`): sub and ships are 2D positions
  in metres (x east, y north) + depth + heading + speed. Interior roll/pitch/shake is visual,
  driven from the sim.
- **Stations read and write the sim.** Helm/dive write orders; the periscope renders the
  exterior ocean scene (`world/`) from the sub's position; sonar/nav draw sim data in 2D.
- **Networking** (`autoload/net.gd`): ENet listen-server on UDP 7000, up to 8 peers. The
  host is authoritative for sim, AI, damage and stations; clients send intents with
  `@rpc("any_peer")` which the host validates. Player avatars are owner-authoritative and
  synced with `MultiplayerSynchronizer`. The sim state is broadcast from the host at 10 Hz.
- **Three boats** (`data/subs/`): the host picks one; `SubInterior` builds it from its layout.
  A client builds the boat when the host's first crew state tells it which (`crew.sub`), so
  player spawns carry their position (`[id, pos]`) rather than reading the interior.
- **Damage** lives in the sim too (`OceanWorld.hull`), stepped on the host and replicated in
  the snapshot; the interior just draws it. Crew-side state (who holds which tool, stats,
  the patrol result) is in `Game.crew`.
- **Data** in `data/` as `.tres` resources (sub classes, ship classes) so tuning is editing numbers.
- The sim has no rendering dependency so it is unit-tested headless.

### Layout
| Path | Holds |
|---|---|
| `autoload/` | `settings.gd` (`Settings`: volumes, graphics, mouse, rebound keys in user://settings.cfg; loads first), `controls.gd` (input map, rebindable from Settings), `net.gd` (host/join, CLI args), `sim.gd` (ocean world, host-run, replicated), `music.gd` (`Music`: crossfaded soundtrack and stings), `sfx.gd` (sound one-shots and loops, on the Effects bus; music goes on Music, crew voices on Voice) |
| `game/` | `bot_crew.gd` (bot crewmen: post, orders, the host's brains for every station), `game.gd`: patrol root — builds boat, spawns crew, owns crew state (doors, stations, tubes) and the host-side request RPCs; `tutorial.gd`: the training courses (one per crew job, with crew calls played for you, and the whole boat): checklists and scripts; `profile.gd`: each player's career, rank and look (user://profile.cfg) |
| `assets/` | `textures/` (grey detail maps from `tools/make_textures.py`), `audio/` (sounds from `tools/make_sounds.sh`): generated, regenerate rather than hand-edit |
| `tools/` | `make_music.py` (the soundtrack, numpy + ffmpeg), `publish.sh`: export the pack to the NAS drop for the launcher; `ship_gallery.gd`: one ship model close up, for screenshots |
| `sim/` | pure simulation classes: sub (incl. battery, diesels, ballast, HP air), `air.gd` (CO2/O2, smoke, scrubber), `tdc.gd` (marks → track → gyro), `formations.gd` (convoy, task force, hunter-killer), `conditions.gd` (night, sea state, layer), `aircraft.gd` (carrier search planes), `sandbox.gd` (open patrol director), ships (gunfire on a surfaced boat), torpedoes, depth charges, `detection.gd`, `ship_ai.gd` (escort state machine), `hull.gd` (water, leaks, fires, broken stations), `whale.gd` (whales: wander, breathe, sing; false sonar contacts), `seabed.gd` (islands, reefs, seamounts, shelves: floor depth, laid out per patrol clear of every track; grounding, ships steering clear) |
| `interior/` | `sub_interior.gd` builds any boat from `LAYOUTS` (compartments fore to aft; the control room ends at z 0), doors, tool racks, parts crate, `damage_view.gd` (draws the hull state), `porthole.gd`, `bot_view.gd` (a bot crewman at his station), `jukebox.gd` |
| `stations/` | station base class and each station |
| `player/` | first-person crew controller (emotes too), `crewman.gd` (the crewman's body and face from a look), held tools (`tools.gd`), proximity voice (`voice.gd`) |
| `world/` | exterior ocean scene, ocean shader, `toon.gdshader` (the painted toon look on every opaque primitive, via `Build.mat`), ship models, `terrain_view.gd` (islands and sea floor meshes from the seabed), `sea_life_view.gd` (whales, fish schools, sharks, octopus), `porthole_eye.gd` (a second camera in the ocean for the porthole you look at) |
| `ui/` | main menu, HUD, station overlays, `chart_view.gd` (the plot), `pause_menu.gd` (Esc), `settings_menu.gd`, `sailor_editor.gd` (make your crewman), `bot_orders.gd` (E at a bot) |
| `data/` | `.tres` balance data and their `Resource` scripts: `subs/`, `ships/` (8 classes), `missions/` (patrols: groups + objectives; `MissionData.KEYS` is the menu order) |
| `tests/` | headless test runner + `test_*.gd` |

### Run
The quick way, from any clone (imports the project after changes, uses port 7845 like the
launcher, updates `main` from GitHub first; see "Playing with others"):
```
./play                      # the menu
./play host [mission] [sub] # e.g. ./play host sandbox narwhal
./play training [course]    # helm scope torpedo sonar damage engine, or full (default)
./play join [address]       # default 192.168.1.76: lando's gaming-pc over the homelab VPN
./play host -- --name Lando # anything after -- goes to the game
```
`make test` runs the unit tests and the training walkthrough. Godot directly:
```
godot --path .                      # main menu
godot --path . -- --host            # host straight away
godot --path . -- --join 127.0.0.1  # join straight away
godot --path . -- --training [course]  # host a training course (the tutorial): helm, scope, torpedo, sonar, damage, engine, full
godot --path . -- --mission <key>   # host a patrol: convoy, tankers, hunted, carrier, task_force, sandbox
godot --path . -- --sub s_boat      # the boat to take out: s_boat, gato (default), narwhal
```
Two-player test on one machine: start one with `--host`, one with `--join 127.0.0.1`.
Testing aids: `--name <n>`, `--spawn x,y,z` (start the local player there, e.g.
`--spawn 0.6,0.1,-20.2` = torpedo room), `--address <ip>` (prefill the join box), `--look <deg>` (spawn turned that far right), `--station <id>` (man that station on arrival: `helm`, `dive`, `ballast`, `periscope`, `tdc`, `sonar`, `tube_1`.., `engine`, `air`), `--port <n>` (default 7000), `--test-charges` (host: fixed seed, and a pattern
goes off around the boat 3 s in and the helm is knocked out; leak/fire positions are printed), `--test-voice` (this player talks a 440 Hz tone the whole time, to check voice without a microphone), `--bots helm,dive,...` (host: posts bot crewmen to those stations at the start; handy solo), `--reef` (host: the boat starts stopped at 9 m just off an island's reef, beam on, a whale close by), `--depth <m>` (host: the patrol starts at that keel depth; 22.5 puts a Gato's raised scope just under), `--test-torpedo` (host: a spread of three fired from the bow 3 s in, to see the tracks), `--test-win` (host: every ship sinks 4 s in, so objectives tick and the debrief shows), `--test-air` (host: foul air, and a fire in the shut-in, smoke-filled control room: whoever is in there passes out). F10 leaves to the menu.

### Dedicated server (lando's mini-server)
`--server` hosts a patrol with no player of its own. Run it headless; it logs to stdout
(`server: ...` lines: hosting, who came aboard / left, patrol results, fresh patrols).
- The patrol waits (the sim is paused) while nobody is aboard, and starts when the first
  crewman joins. Up to 8 players (all slots are for players).
- 90 s after a debrief, or after the boat has sat empty for 10 minutes (so a crew can drop and
  rejoin the same patrol), it starts a fresh one; anyone still connected goes back to their
  menu with "join again".
- From a clone: `./play server [mission] [sub]` (default `sandbox gato`, port 7845).
- Directly (e.g. a systemd unit):
  `godot --headless --path <checkout> -- --server --mission sandbox --sub gato --port 7845`
  or with the published pack: `godot --headless --main-pack sub-of-seas.pck -- --server ...`.
  Players join it like any host. A source checkout reports build `dev` (add `--build <id>`
  to pin one); a pack reports its commit and turns away other builds.
- Network traffic is ZSTD-compressed by ENet, so the server and every player must run a build
  from after that change.

### Playing with others (Blaney)
**From source** (both have the repo): lando runs `./play host <mission>` on gaming-pc,
Blaney runs `./play join` over the homelab VPN. `./play` keeps you on the latest version: on
`main` it fast-forwards to `origin/main` before starting (it stops if you have uncommitted
changes), on another branch it warns when `main` has moved on and host/join ask before going
on, and hosting with unpushed commits warns that the joiner won't have them. It never asks for
a GitHub login; without one it skips the check. A source build reports itself as
`dev-<commit>` (shown on the main menu; `dev` without `./play`), and any host lets a dev build
in, so compare the commits on the menu if something seems off.

**From the published pack** (friends without the repo): `tools/publish.sh` exports one `.pck`
(no export templates needed) to the NAS drop `/mnt/nas/public/sub-of-seas/`, and the
`sub-of-seas` launcher from nixos-config (`modules/nixos/programs/sub-of-seas.nix`, on
gaming-pc and blaney-pc) downloads a new one on its next start and runs it on port 7845.
Blaney joins `192.168.1.76:7845` over the homelab VPN (the Batman forward to gaming-pc).
The build id (commit) is baked into the pack; a host turns away a different build, except
`dev` (running from source). Publish only committed, tested work.

### Controls
WASD + mouse, E interact, Space jump, 1–5 emotes (wave, salute, jig, point, cheer), Q leave station, Esc pause menu (settings, leave),
Tab next station in a cluster, B post a bot crewman to the empty station you look at (B at a bot stands him down; E at a bot gives orders: T orders/own initiative, plus his station's keys)
(helm/dive; periscope/TDC in the conning tower; the S-boat's conn: helm, periscope, sonar, TDC).
Helm: W/S telegraph, A/D rudder. Dive: W/S depth ±5 (Shift ±1), 1–4 presets.
Periscope: mouse train, Z power, R raise/lower, F stadimeter, M mark for the TDC.
TDC (conning tower, starboard): W/S target speed ±1 kn, A/D course ±5°, C clear marks, T send to the tubes (gyros follow).
Chart table (control room, starboard aft): W/S or wheel zoom, LMB pencil mark, RMB rub out. Sonar: M puts the bearing on the chart. Sonar is the listening station: the hydrophone plays the contact it is trained on in your headphones (whales too; hold it there 3 s for the readout). Tubes: L reload, F flood,
O outer door, A/D gyro, Space fire. Sonar: A/D or mouse train, P active ping.
Engine (after end of the engine room): 1/2 start/stop a diesel (surfaced only; stop them before diving).
Ballast (control room, port aft): V vents (flood to dive), B blow (to surface), X twice emergency blow.
Air (engine room, starboard fwd): C fresh CO2 canister, O oxygen bleed.
Rec room (Gato, Narwhal: aft of the mess): darts station (mouse aim, LMB/Space throw), E at the jukebox for the next record.
Voice: hold Caps Lock to talk (proximity: you hear crewmates near you).
Tools: E at a rack takes one, hold LMB on a leak/fire/broken station to work, LMB with the pump sets it
down at your feet (E picks it up), G puts a tool down. Wrecked gear needs a spare parts box (crate in the engine room, aft port) fitted with LMB before the wrench.

### Test
```
godot --headless --path . --quit-after 120          # script/parse errors
godot --headless --path . -s tests/run_tests.gd     # unit tests, exit code 1 on failure
godot --headless --path . -s tests/tutorial_walkthrough.gd [-- <course>]  # plays a training course (whole boat ~1 min); `make walkthrough` plays them all
```
Then run it in xvfb and look at screenshots (see `../CLAUDE.md`).

### Conventions
- Static typing everywhere; `snake_case` files, `PascalCase` `class_name`s.
- Commit messages `type(scope): description`. Commit whenever the game is playable.
- Keep `docs/roadmap.md` ticked and this file current when the architecture changes.

## Working together: git and PRs

sub-of-seas is **lando's** repo (`github.com/landonreekstin/sub-of-seas`, private).
**Blaney** (`insideabush` on his PC, `cblaney00` on GitHub) works on it too, from his own
clone that `vibe` opens. These rules follow the ones in lando's NixOS config, and they apply
to every session in every clone.

**Who you are working for** decides the rules: lando when the clone is
`~/gamedev/sub-of-seas` on lando's machine, and Blaney when it is
`/home/insideabush/projects/sub-of-seas` (`.vibe-project` there has `shared=`).

### Every session, before anything else

1. `git fetch origin`. Read `git log --oneline HEAD..origin/main` to see what the other
   person pushed since last time.
2. `gh pr list --repo landonreekstin/sub-of-seas` shows what is open. Read the comments and
   reviews on the open `blaney/` PRs (`gh pr view <n> --comments`).
   - In **Blaney's** sessions: lando's comments come first. Make the changes he asks for
     on that PR's branch, push, and reply on the PR (`gh pr comment`) saying what changed.
   - In **lando's** sessions: if a PR from Blaney is waiting, say so in one line.
3. Start from an up-to-date `main`. On `main`, run `git merge --ff-only origin/main`. On a
   branch, run `git rebase origin/main`, then `git push --force-with-lease` if the branch
   is already on GitHub. Never pull other people's work in any other way.

### Blaney's changes: always a `blaney/` branch and a PR

- **Never commit to `main`, never push to `main`, never merge anything into `main`.** His
  clone has git hooks that refuse it. Never get around them with `--no-verify`.
- One branch per change he asks for, named `blaney/<what>` (for example
  `blaney/sonar-waterfall`). Branch from an up-to-date `origin/main`. If he carries on with
  something that already has a PR open, use that PR's branch.
- Open the PR with `gh pr create --base main` and **stop there**. Lando reviews and merges
  it. The PR description says in plain English what changed and how to try it.
- Push after every commit. The branch on GitHub is what lando reviews and his backup.
- Never run `tools/publish.sh`: only lando publishes builds to the NAS drop.

### Lando's changes

- Lando may commit straight to `main`. Bigger or riskier work goes on a
  `feat/`/`fix/`/`tweak/` branch with a PR, the same as in the NixOS config.
- **Merge Blaney's PRs only when lando asks**, after the game has been run on that branch:
  `gh pr checkout <n>`, run the tests (see "Test"), play it. Merge with
  `gh pr merge <n> --merge --delete-branch`.
- **Always delete a branch once it is merged**, locally and on GitHub
  (`git branch -d <b>`, `git push origin --delete <b>`, then `git fetch --prune`). At the
  start of a session, delete any merged branches left over
  (`git branch --merged origin/main`, `git branch -r --merged origin/main`). Never delete
  a branch that isn't merged.
- Publish (`tools/publish.sh`) only from a tested `main`, so the pack Blaney plays is code
  that is on GitHub.

### Look and feel: `docs/style.md`

Both of us make calls about how the game looks, sounds and feels, and Blaney's count as
much as lando's. They have to outlive the chat they were made in, so `docs/style.md` is
where they live.
- **Before any change someone will see, hear or feel, read `docs/style.md` and follow it.**
  New models, colours, UI, sounds, controls, movement, camera, station screens, writing
  tone. If what you are asked for doesn't fit it, say so, and ask whether this is a new
  direction.
- **Every time either of us gives a look-and-feel direction, log it.** That includes ones
  given in passing while playtesting ("the water looks too green", "the periscope should
  turn slower"). Add a row to its direction log in their words with the date and who said
  it. Then update "Current style" to match, in the **same commit** as the change it caused.
  A PR that changes how the game looks or feels without touching `docs/style.md` is
  incomplete.
- Ask a short follow-up when a direction is vague, so the logged rule can be followed by
  someone who wasn't there. For example: "too green: the flood water, or the walls?"
- If it contradicts an earlier direction from the *other* person, follow the new one on the
  branch, log it, and add a **"Style conflict"** heading to the PR description. Don't
  quietly overrule either of you.
- In a PR, a separate **"Look and feel"** heading lists the directions it added.

### For both: verify before you commit

**Never commit or open a PR for a change you haven't seen working.** Passing tests is not
enough.
- The unit tests and the training walkthrough must pass (see "Test").
- Run the game and look at it: screenshot it under `xvfb-run` (see `../CLAUDE.md`) and open
  the picture. For anything you control or feel, the person you are working for plays it.
  For anything networked, run a host and a client (`--host` / `--join 127.0.0.1`, see "Run").
- Commit messages are `type(scope): description`, in lowercase with no period at the end.
  The types are `feat`, `fix`, `tweak`, `art`, `docs`, `test` and `chore`, for example
  `feat(sonar): add a waterfall display`. **Do not add Co-Authored-By or AI attribution
  lines.**
- Keep this file and `docs/style.md` current. They are how the other person's sessions find
  out what changed.
