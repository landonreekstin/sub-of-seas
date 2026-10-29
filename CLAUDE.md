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
- **Damage** lives in the sim too (`OceanWorld.hull`), stepped on the host and replicated in
  the snapshot; the interior just draws it. Crew-side state (who holds which tool, stats,
  the patrol result) is in `Game.crew`.
- **Data** in `data/` as `.tres` resources (sub classes, ship classes) so tuning is editing numbers.
- The sim has no rendering dependency so it is unit-tested headless.

### Layout
| Path | Holds |
|---|---|
| `autoload/` | `controls.gd` (input map), `net.gd` (host/join, CLI args), `sim.gd` (ocean world, host-run, replicated) |
| `game/` | `game.gd`: patrol root — builds boat, spawns crew, owns crew state (doors, stations, tubes) and the host-side request RPCs; `tutorial.gd`: the training patrol's checklist and script |
| `tools/` | `publish.sh`: export the pack to the NAS drop for the launcher |
| `sim/` | pure simulation classes: sub (incl. battery, diesels, ballast, HP air), `air.gd` (CO2/O2, smoke, scrubber), `tdc.gd` (marks → track → gyro), ships, torpedoes, depth charges, `detection.gd`, `ship_ai.gd` (escort state machine), `hull.gd` (water, leaks, fires, broken stations) |
| `interior/` | sub interiors built from primitives, doors, compartments, tool racks, `damage_view.gd` (draws the hull state) |
| `stations/` | station base class and each station |
| `player/` | first-person crew controller, held tools (`tools.gd`) |
| `world/` | exterior ocean scene, ocean shader, ship models |
| `ui/` | main menu, HUD, station overlays |
| `data/` | `.tres` balance data and their `Resource` scripts |
| `tests/` | headless test runner + `test_*.gd` |

### Run
```
godot --path .                      # main menu
godot --path . -- --host            # host straight away
godot --path . -- --join 127.0.0.1  # join straight away
godot --path . -- --training      # host the training patrol (the tutorial)
```
Two-player test on one machine: start one with `--host`, one with `--join 127.0.0.1`.
Testing aids: `--name <n>`, `--spawn x,y,z` (start the local player there, e.g.
`--spawn 0.6,0.1,-20.2` = torpedo room), `--address <ip>` (prefill the join box), `--look <deg>` (spawn turned that far right), `--station <id>` (man that station on arrival: `helm`, `dive`, `ballast`, `periscope`, `tdc`, `sonar`, `tube_1`.., `engine`, `air`), `--port <n>` (default 7000), `--test-charges` (host: fixed seed, and a pattern
goes off around the boat 3 s in and the helm is knocked out; leak/fire positions are printed), `--test-air` (host: foul air, and a fire in the shut-in, smoke-filled control room: whoever is in there passes out). F10 leaves to the menu.

### Playing with others (Blaney)
Others play the **published pack**, not the source: `tools/publish.sh` exports one `.pck`
(no export templates needed) to the NAS drop `/mnt/nas/public/sub-of-seas/`, and the
`sub-of-seas` launcher from nixos-config (`modules/nixos/programs/sub-of-seas.nix`, on
gaming-pc and blaney-pc) downloads a new one on its next start and runs it on port 7845.
Blaney joins `192.168.1.76:7845` over the homelab VPN (the Batman forward to gaming-pc).
The build id (commit) is baked into the pack; a host turns away a different build, except
`dev` (running from source). Publish only committed, tested work.

### Controls
WASD + mouse, E interact, Space jump, Q/Esc leave station, Tab next station in a cluster.
Helm: W/S telegraph, A/D rudder. Dive: W/S depth ±5 (Shift ±1), 1–4 presets.
Periscope: mouse train, Z power, R raise/lower, F stadimeter, M mark for the TDC.
TDC (conning tower, starboard): W/S target speed ±1 kn, A/D course ±5°, C clear marks, T send to the tubes (gyros follow). Tubes: L reload, F flood,
O outer door, A/D gyro, Space fire. Sonar: A/D or mouse train, P active ping.
Engine (after end of the engine room): 1/2 start/stop a diesel (surfaced only; stop them before diving).
Ballast (control room, port aft): V vents (flood to dive), B blow (to surface), X twice emergency blow.
Air (engine room, starboard fwd): C fresh CO2 canister, O oxygen bleed.
Tools: E at a rack takes one, hold LMB on a leak/fire/broken station to work, LMB with the pump sets it
down at your feet (E picks it up), G puts a tool down. Wrecked gear needs a spare parts box (crate in the engine room, aft port) fitted with LMB before the wrench.

### Test
```
godot --headless --path . --quit-after 120          # script/parse errors
godot --headless --path . -s tests/run_tests.gd     # unit tests, exit code 1 on failure
godot --headless --path . -s tests/tutorial_walkthrough.gd  # plays the whole training patrol (~1 min)
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
  `gh pr merge <n> --merge`.
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
