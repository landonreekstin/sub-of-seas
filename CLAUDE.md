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
- `docs/notes.md` — where things stand, newest first: read it at the start, update it at every pause
- `docs/capabilities.md` — what Claude does alone vs what needs lando
- `docs/credits.md` — every recording in the game and its licence

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
- **Five boats** (`data/subs/`, the Titan from `interior/titan_layout.gd`: one tube, the pilot's game controller): the host picks one; `SubInterior` builds it from its layout
  (the Typhoon from `interior/typhoon_layout.gd`: rooms side by side and on two levels, each on its own root so
  `SubInterior._cull_rooms` draws only what you could see).
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
| `autoload/` | `settings.gd` (`Settings`: volumes, graphics, mouse, rebound keys in user://settings.cfg; loads first), `controls.gd` (input map, rebindable from Settings), `net.gd` (host/join, CLI args), `sim.gd` (ocean world, host-run, replicated), `music.gd` (`Music`: crossfaded soundtrack, its Soundtrack bus, jukebox included, is hushed while anyone plays an instrument), `sfx.gd` (sound one-shots and loops, on the Effects bus; music goes on Music, crew voices on Voice) |
| `game/` | `pastimes.gd` (`Pastimes`: arm wrestling, blackjack, the galley's meals, fishing catches: the rules and the crew's bests, host-kept in crew state), `fishing.gd` (`Fishing`: the rod off the stern, a local panel), `crew_command.gd` (`CrewCommand`: what the skipper's plain English on the PA means; `BotCrew._carry_out` does it), `band.gd` (`Band`: the ship's band: each instrument's part of the song in time on the sim clock), `wrestling.gd` (`Wrestling`: the deck wrestling rules: moves, turns, who goes in), `deck.gd` (`Deck`: out on deck, and the wrestling bout's view: the casing as collision far above the interior, the view from it through the exterior, crew figures, swimming, side ladders), `bot_crew.gd` (bot crewmen: post, orders, the host's brains for every station), `game.gd`: patrol root — builds boat, spawns crew, owns crew state (doors, stations, tubes) and the host-side request RPCs; `tutorial.gd`: the training courses (one per crew job, with crew calls played for you; crew courses taken together, `CREW_JOBS`, each job held by whoever mans its station, calls from the crewmate holding it; and the whole boat): checklists and scripts; `profile.gd`: each player's career, rank and look (user://profile.cfg) |
| `assets/` | `textures/` (grey detail maps and their `_h` height maps from `tools/make_textures.py`), `audio/` (recordings cut by `tools/make_recorded.py`, a few sounds synthesised by `tools/make_sounds.sh`): generated, regenerate rather than hand-edit; every source is in `docs/credits.md` |
| `tools/` | `samples.py` (real recorded instruments, downloaded once into `tools/.samples/`, not committed), `make_music.py` (the soundtrack played on them, numpy + ffmpeg), `make_shanty.py` (the band's parts, `shanty_<instrument>.ogg`, and the whole band for the jukebox, `music_foggy_dew.ogg`), `make_sounds.sh` then `make_recorded.py` (the sound effects and the jukebox's old records), `publish.sh`: export the pack to the NAS drop for the launcher; `room_tour.gd`: a picture of every room of a boat and what it costs to draw (needs a screen; `xvfb-run` is very slow, and Blaney's graphics card only with his say-so), `cave_look.gd`: a cave for a boat on its own (`-- <sub> out.png air|mouth|inside|over`); `typhoon_looks.gd`: close-ups of a Typhoon's doors, signs, notebooks and band; `look_at.gd`: pictures from chosen spots in a boat (`-- <sub> <dir> <type,x,dz,yaw> ...`, needs a screen); `ship_gallery.gd`: one ship model close up, for screenshots (`-s tools/ship_gallery.gd -- <class | crew | sealife | plane | own[_<sub>]> [out.png] [eye | x,y,z,tx,ty,tz]` saves one and quits; `own` is our boat on the surface, `eye` the gunlayer's view; it runs without the autoloads, so it can't use `Player`, `Sim` and the like) |
| `sim/` | pure simulation classes: `enemy_sub.gd` (`EnemySubAI`: an enemy submarine's brain), `chart_known.gd` (`ChartKnown`: what the boat has seen, for the limited map in those fights), sub (incl. battery, diesels, ballast, HP air), `air.gd` (CO2/O2, smoke, scrubber), `tdc.gd` (marks → track → gyro), `formations.gd` (convoy, task force, hunter-killer), `conditions.gd` (night, sea state, layer, rain squalls drifting on the wind), `aircraft.gd` (carrier search planes), `sandbox.gd` (open patrol director), ships (gunfire on a surfaced boat), torpedoes, our deck gun's shells (`OceanWorld.fire_gun`: fall of shot, hits), depth charges, `detection.gd`, `ship_ai.gd` (escort state machine), `hull.gd` (water, leaks, fires, broken stations), `whale.gd` (whales: wander, breathe, sing; false sonar contacts), `realism.gd` (the host's arcade ↔ realism level: handling, duds, damage, air, escorts), `seabed.gd` (islands, reefs, seamounts, shelves, trenches and caves (`roof_depth`; `OceanWorld._check_cave` scrapes): floor depth, laid out per patrol clear of every track; grounding, ships steering clear) |
| `interior/` | `build.gd` (`Build`: bevelled boxes, lathed shapes, curved hull panels, torpedoes, the toon materials), `sub_interior.gd` builds any boat from `LAYOUTS` (compartments fore to aft; the control room ends at z 0), doors, tool racks, parts crate, `damage_view.gd` (draws the hull state), `living.gd` (`Living`: the galley and its cook, laid tables, lived-in bunks, photos and pin-ups), `porthole.gd`, `typhoon_layout.gd` (`TyphoonLayout`: the Typhoon's five hulls, 19 rooms, cross passages, its sailors), `band_crew.gd` (forty hands at the band), `bot_view.gd` (a bot crewman at his station), `jukebox.gd`, `pa_mic.gd` (the PA microphone), `fun_spot.gd` (`FunSpot`: a pastime's soft glow and name when you're near, listed on the T card) |
| `stations/` | station base class and each station (`notebook_station.gd`: the Typhoon's first mate's and skipper's notebooks; `reactor_station.gd`: her reactor controls; `yoke_station.gd`: her command bay's helmsman's and planesman's yokes; `holo_station.gd`: the skipper's chair and his hologram of the water; `nav_table_station.gd`: the sand table's relief from the seabed; `arm_station.gd`, `cards_station.gd`, `galley_station.gd`: the pastimes' seats and the galley range; `pilot_station.gd`: the Titan's pilot, a game controller or the keyboard; `camera_station.gd`: the outside cameras, SubViewports on the exterior world that see our own boat's render layer) |
| `player/` | first-person crew controller (emotes too), `crewman.gd` (the crewman's body and face from a look), held tools (`tools.gd`), proximity voice (`voice.gd`) |
| `world/` | exterior ocean scene (and the deck gun's view: `eye_mode`), ocean shader, `toon.gdshader` (the painted toon look on every opaque primitive, via `Build.mat`: detail map, height-map bump and cavity), `toon_sky.gd` (`ToonSky`: the painted sky, clouds by sea state, stars at night), ship models, `own_boat.gd` (`OwnBoat`: our own boat from outside, each class, and the one shape `Deck` walks on; its gun), `terrain_view.gd` (islands and sea floor meshes from the seabed), `cave_view.gd` (a cave's ridge and tunnel), `sea_life_view.gd` (whales, fish schools, sharks, octopus, swimming them), `creatures.gd` (`Creatures`: their bodies), `porthole_eye.gd` (a second camera in the ocean for the porthole you look at); our own boat model is always placed (dived, at her depth) on render layer `ExteriorWorld.OWN_LAYER`, which the periscope and portholes don't see, `weather_view.gd` (squalls: cloud base, `rain_curtain.gdshader`, rain past the eye) |
| `ui/` | main menu, HUD, station overlays, `chart_view.gd` (the plot), `pause_menu.gd` (Esc), `settings_menu.gd`, `sailor_editor.gd` (make your crewman), `bot_orders.gd` (E at a bot), `pa_panel.gd` (typing into the PA), `things_to_do.gd` (`ThingsToDo`: the T card) |
| `data/` | `.tres` balance data and their `Resource` scripts: `subs/`, `ships/` (8 classes), `missions/` (patrols: groups + objectives; `MissionData.KEYS` is the menu order) |
| `tests/` | headless test runner + `test_*.gd` |

### Run
The quick way, from any clone (imports the project after changes, uses port 7845 like the
launcher, updates `main` from GitHub first; see "Playing with others"):
```
./play                      # the menu
./play host [mission] [sub] # e.g. ./play host sandbox narwhal
./play training [course]    # helm scope torpedo sonar damage engine, or full (default); with friends: attack control party
./play join [address]       # default 192.168.1.76: lando's gaming-pc over the homelab VPN
./play host -- --name Lando # anything after -- goes to the game
```
`make test` runs the unit tests and the training walkthrough. Godot directly:
```
godot --path .                      # main menu
godot --path . -- --host            # host straight away
godot --path . -- --join 127.0.0.1  # join straight away
godot --path . -- --training [course]  # host a training course (the tutorial): helm, scope, torpedo, sonar, damage, engine, full; crew courses: attack, control, party
godot --path . -- --mission <key>   # host a patrol: convoy, tankers, hunted, carrier, task_force, sub_duel, sandbox; on the Typhoon: cw_convoy, cw_barrier, cw_battlegroup, cw_duel, cw_sandbox, cave (every era: cw_cave, titan_cave); on the Titan: titan_dive
godot --path . -- --sub s_boat      # the boat to take out: s_boat, gato (default), narwhal, typhoon, titan
godot --path . -- --realism realistic  # host: arcade (default), standard, realistic (sim/realism.gd); training plays at it too
```
Two-player test on one machine: start one with `--host`, one with `--join 127.0.0.1`.
Testing aids: `--name <n>`, `--spawn x,y,z` (start the local player there, e.g.
`--spawn 0.6,0.1,-20.2` = torpedo room), `--address <ip>` (prefill the join box), `--look <deg>` (spawn turned that far right), `--station <id>` (man that station on arrival: `helm`, `dive`, `ballast`, `bilge`, `periscope`, `tdc`, `sonar`, `tube_1`.., `engine`, `air`, `gun`, `ammo`, `sand_table`, `cameras`), `--port <n>` (default 7000), `--test-charges` (host: fixed seed, and a pattern
goes off around the boat 3 s in and the helm is knocked out; leak/fire positions are printed), `--test-voice` (this player talks a 440 Hz tone the whole time, to check voice without a microphone), `--bots helm,dive,...` (host: posts bot crewmen to those stations at the start; handy solo), `--squall [over|ahead]` (host: a rain squall over the boat, or 4 km dead ahead), `--deck` (climb out on deck once aboard; the boat must be surfaced, so host with `--depth 0`), `--reef` (host: the boat starts stopped at 9 m just off an island's reef, beam on, a whale close by), `--depth <m>` (host: the patrol starts at that keel depth; 22.5 puts a Gato's raised scope just under), `--test-breach` (host: an emergency blow 3 s in; with `--depth 80` she crash-surfaces), `--test-torpedo` (host: a spread of three fired from the bow 3 s in, to see the tracks), `--test-win` (host: every ship sinks 4 s in, so objectives tick and the debrief shows), `--test-air` (host: foul air, and a fire in the shut-in, smoke-filled control room: whoever is in there passes out). F10 leaves to the menu.

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
  (add `--realism standard` or `realistic` for a harder boat; `./play server sandbox gato -- --realism realistic`)
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
WASD + mouse, E interact, Space jump, Shift (hold) sprint: 2.1× forward, louder feet, Ctrl (hold) crouch: lower, half speed, near-silent feet, 1–5 emotes (wave, salute, jig, point, cheer), Q leave station, Esc pause menu (settings, leave),
Tab next station in a cluster, B post a bot crewman to the empty station you look at (B at a bot stands him down; E at a bot gives orders: T orders/own initiative, plus his station's keys)
(helm/dive; periscope/TDC in the conning tower; the S-boat's conn: helm, periscope, sonar, TDC).
Helm: W/S telegraph, A/D rudder. Dive: W/S depth ±5 (Shift ±1), 1–4 presets.
Periscope: mouse train, Z power, R raise/lower, F stadimeter, M mark for the TDC (Standard/Realistic). In Arcade there is no TDC or gyro: the scope shows a red AIM mark leading each ship and a BOW tick; turn the boat until BOW is under AIM (it goes green, FIRE!) and fire straight out of the tube.
TDC (conning tower, starboard): W/S target speed ±1 kn, A/D course ±5°, C clear marks, T send to the tubes (gyros follow).
Chart table (control room, starboard aft): W/S or wheel zoom, LMB pencil mark, RMB rub out. Sonar: M puts the bearing on the chart. Sonar is the listening station: the hydrophone plays the contact it is trained on in your headphones (whales too; hold it there 3 s for the readout). Tubes: L reload, F flood,
O outer door, A/D gyro, Space fire. A crewmate standing by the tube (off station) makes a reload 1.7× quicker. Sonar: A/D or mouse train, P active ping.
Engine (after end of the engine room): 1/2 start/stop a diesel (surfaced only; stop them before diving).
Ship's band (rack in the rec room; the S-boat's in the navigation room): E takes an instrument, hold LMB to play your part of the song, G puts it back.
Navigation room (aft of the control room): the sand table (E for a closer look) and the outside cameras' console (E, then 1-6 for the big screen: bow, stern, port, starboard, bridge, keel).
Out on deck (any time, for now; dived you come out into the sea in the dive suit): look up at the bridge hatch over the gun's ladder, E climbs out; E at the deck hatch goes below; off the side you swim, E at a side ladder climbs back aboard. No diving while anyone is out without a suit.
God mode: "god mode" on the PA (again or "god mode off" to stop), for whoever says it: 3x on foot, 8x swimming (Shift 16x), can't be knocked out (`crew.god`, `Player.godly()`).
Wrestling (aft casing, the painted ring): two step in to start; 1 push, 2 arm drag, 3 body lock, 4 suplex (needs a lock), 5 brace; drive him off his edge.
Ballast (control room, port aft): V vents (flood to dive), B blow (to surface), X twice emergency blow.
Bilge pump (control room, forward bulkhead, port of the door): P start/stop. Drains the wettest compartment 4× a portable pump, off the battery; escorts can hear it.
Air (navigation room, starboard fwd): C fresh CO2 canister, O oxygen bleed.
Deck gun (surfaced only; up the bridge-hatch ladder in the conning tower's forward port corner, or aft in the S-boat's control room): mouse train (150° either side of the bow), W/S range ±100 m (Shift ±25), wheel ±50 m, F rangefinder on the ship in the sight, Z telescope, LMB/Space fire. Watch the fall of shot: short is a miss, a little over still hits a tall ship. Diving clears the deck.
Ammunition scuttle (in the deck of the crew's mess; S-boat: the wardroom): hold Space to pass rounds up to the gun's ready-use locker. Firing gives the boat away to every ship within 12 km.
T: the things-to-do card (every pastime aboard, where, its keys, the crew's records).
Pastimes: arm wrestling (crew's mess forward table; S-boat: the wardroom table): tap Space. Blackjack (rec room card table; S-boat: wardroom): Space deals / hits, S stands. Galley range: Space flips in the green, three flips a meal. Fishing (out on deck, the stern rail): E, Space strikes, hold LMB to reel in the green, Q puts the rod down. B at an empty seat sits a bot down to play you.
Rec room (Gato, Narwhal: aft of the mess): darts station (mouse aim, LMB/Space throw), E at the jukebox for the next record.
PA microphone (control room, after bulkhead port of the door): E, type an order in plain English, Enter; the crew do it (every order: `docs/pa_commands.md`, `CrewCommand.HELP`; "take us through the cave" and they do). J at any station hands it to a bot.
Titan pilot (aft, on the floor): W/S thrust, A/D turn, hold R up / F down (Shift gently), X twice drops the weights; with a game controller: left stick, triggers, B twice.
Typhoon command bay: the helmsman's and planesman's yokes facing the bow (Tab between them). Planesman: hold W push down, S pull up (Shift gently), 1-4 presets; helmsman: A/D or mouse rudder, C centre, W/S engine order. Skipper's chair (port of the scope): H the hologram for everyone.
Ballast X twice (emergency blow) from depth, or "crash surface" on the PA: she breaches.
"All hands on deck" on the PA (any boat): every post manned, the boat filled, the crew work the objective themselves until "stand down".
Typhoon: "all hands" on the PA (command bay, after bulkhead) fills the boat; "band play" and "stop the music". First mate's list (command bay): E, F turns out the damage parties. Skipper's notebook: E, R reads the mate's list. Reactor controls: after end of the port turbine room. Up the ladder in the centre passage to the command bay.
Voice: hold Caps Lock to talk (proximity: you hear crewmates near you).
Tools: E at a rack takes one, hold LMB on a leak/fire/broken station to work, LMB with the pump sets it
down at your feet (E picks it up), G puts a tool down. Wrecked gear needs a spare parts box (crate in the engine room, aft port) fitted with LMB before the wrench.

### Test
```
godot --headless --path . --quit-after 120          # script/parse errors
godot --headless --path . -s tests/run_tests.gd     # unit tests, exit code 1 on failure
godot --headless --path . -s tests/party_walkthrough.gd -- <sub>   # damage parties stay inside the boat, through shut doors
godot --headless --path . -s tests/door_walk.gd -- typhoon         # a player walks through every door, both ways
godot --headless --path . -s tests/breach_hatch.gd -- <sub> [pa | ballast | planesman]  # crash surface from 80 m with bots aboard: the hatch opens and stays open
godot --headless --path . -s tests/god_out.gd -- <sub>             # out of the hatch dived, god mode: catch her up at flank, back below
godot --headless --path . -s tests/cave_crew.gd -- <sub> [pa | all_hands]   # the bot crew take her through the cave alone
godot --headless --path . -s tests/deck_walk.gd -- <sub>           # out of the hatch, along the deck, back down; swim and climb aboard
godot --headless --path . -s tests/pastime_walkthrough.gd -- <sub> # bots play every pastime; the T card lists them
godot --headless --path . -s tests/all_hands_walkthrough.gd [-- <mission> <sub>]  # "all hands on deck": the crew sink a ship on their own
godot --headless --path . -s tests/tutorial_walkthrough.gd [-- <course> [realism]]  # plays a training course (whole boat ~1 min) at arcade, or the level given; `make walkthrough` plays them all, and scope/torpedo at realistic
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
4. See what the other person has **in progress**: `git branch -r --no-merged origin/main`
   and `git log --oneline origin/main..origin/<branch>` for each (`wip(...)` commits are
   unfinished work), plus draft PRs in `gh pr list`. Before starting something, check it
   isn't already being built there; if it touches the same code, say so and build on it
   rather than alongside it.

### For both: push work in progress as you go

lando: "commit and push to a branch as wip so his Claude can see what's being done". It
applies to **both** of us, in every session:
- Never sit on uncommitted work. Whenever a piece of work is part-done (at the latest at
  each natural pause, before a long test run, and when the session ends or is paused),
  commit it on its branch as `wip(<scope>): <what so far>` (for example
  `wip(sonar): waterfall draws, no scrolling yet`) and push. `wip` commits never go on
  `main`: lando's work in progress goes on a `feat/`/`fix/`/`tweak/` branch, Blaney's on its
  `blaney/` branch.
- A branch with `wip` commits gets a **draft** PR right away (`gh pr create --draft`), whose
  description says what's done and what's still to do. Mark it ready
  (`gh pr ready <n>`) once the work is finished and verified (below); never merge a draft.
- `wip` commits are the one exception to "verify before you commit": they may be
  unfinished, but they must still parse (`godot --headless --path . --quit-after 120`), so
  the other person can check the branch out and run it.

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

**Never commit to `main`, or mark a PR ready or merge it, with a change you haven't seen
working.** (WIP commits on a branch are fine, see above.) Passing tests is not enough.
- The unit tests and the training walkthrough must pass (see "Test").
- Run the game and look at it: screenshot it under `xvfb-run` (see `../CLAUDE.md`) and open
  the picture. For anything you control or feel, the person you are working for plays it.
  For anything networked, run a host and a client (`--host` / `--join 127.0.0.1`, see "Run").
- Commit messages are `type(scope): description`, in lowercase with no period at the end.
  The types are `feat`, `fix`, `tweak`, `art`, `docs`, `test`, `chore` and `wip` (work in
  progress, see above), for example
  `feat(sonar): add a waterfall display`. **Do not add Co-Authored-By or AI attribution
  lines.**
- Keep this file and `docs/style.md` current. They are how the other person's sessions find
  out what changed.
