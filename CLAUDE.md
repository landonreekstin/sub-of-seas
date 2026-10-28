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
(private, solo — small work straight to `main`, bigger work on `feat/` branches).

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
- **Data** in `data/` as `.tres` resources (sub classes, ship classes) so tuning is editing numbers.
- The sim has no rendering dependency so it is unit-tested headless.

### Layout
| Path | Holds |
|---|---|
| `autoload/` | `controls.gd` (input map), `net.gd` (host/join, CLI args), `sim.gd` (ocean world, host-run, replicated) |
| `game/` | `game.gd`: patrol root — builds boat, spawns crew, owns crew state (doors, stations, tubes) and the host-side request RPCs |
| `sim/` | pure simulation classes (sub, ships, torpedoes) |
| `interior/` | sub interiors built from primitives, doors, compartments |
| `stations/` | station base class and each station |
| `player/` | first-person crew controller |
| `world/` | exterior ocean scene, ocean shader, ship models |
| `ui/` | main menu, HUD, station overlays |
| `data/` | `.tres` balance data and their `Resource` scripts |
| `tests/` | headless test runner + `test_*.gd` |

### Run
```
godot --path .                      # main menu
godot --path . -- --host            # host straight away
godot --path . -- --join 127.0.0.1  # join straight away
```
Two-player test on one machine: start one with `--host`, one with `--join 127.0.0.1`.
Testing aids: `--name <n>`, `--spawn x,y,z` (start the local player there, e.g.
`--spawn 0.6,0.1,-20.2` = torpedo room). F10 leaves to the menu.

### Controls
WASD + mouse, E interact, Space jump, Q/Esc leave station, Tab next station in a cluster.
Helm: W/S telegraph, A/D rudder. Dive: W/S depth ±5 (Shift ±1), 1–4 presets.
Periscope: mouse train, Z power, R raise/lower, F stadimeter. Tubes: L reload, F flood,
O outer door, A/D gyro, Space fire.

### Test
```
godot --headless --path . --quit-after 120          # script/parse errors
godot --headless --path . -s tests/run_tests.gd     # unit tests, exit code 1 on failure
```
Then run it in xvfb and look at screenshots (see `../CLAUDE.md`).

### Conventions
- Static typing everywhere; `snake_case` files, `PascalCase` `class_name`s.
- Commit messages `type(scope): description`. Commit whenever the game is playable.
- Keep `docs/roadmap.md` ticked and this file current when the architecture changes.
