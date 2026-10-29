# Roadmap

Each milestone ends playable and committed. Tick items as they land.

## M0 — Foundation
- [x] Repo, docs, CLAUDE.md
- [x] Godot 4.7 project, input map, autoloads (`Net`, `Sim`)
- [x] Headless test runner
- [x] Main menu: host / join by IP, player name
- [x] LAN connect with up to 8 peers, CLI `--host` / `--join <ip>` for testing

## M1 — First dive (vertical slice)
- [x] Greybox Gato interior: forward torpedo room, control room, conning tower (ladder), engine room, doors
- [x] First-person player with networked movement, name tags
- [x] Station framework: enter/exit view, one player per station, cluster switching
- [x] Ocean sim: sub kinematics (speed, turn, depth), world clock
- [x] Helm + dive stations driving the sim (all peers see the result)
- [x] Periscope view: rendered ocean, sky, freighter target, rotate/zoom/raise
- [x] Torpedo tube: load, fire; torpedo run in sim; hit and sink a freighter (sim-tested; not yet sunk one by hand in-game)
- [x] Interior motion: roll/pitch with dive angle and turns

## M2 — The hunter
- [x] Destroyer AI: patrol → detect → hunt → depth-charge attack runs
- [x] Detection model (noise, periscope exposure, active sonar)
- [x] Sonar station (passive bearings, active ping)
- [x] Depth charges → damage: leaks, fires, system damage, shake
- [x] Tools: welding torch, portable pump, extinguisher, wrench; tool racks
- [x] Compartment water levels + flow through open doors; fire spread
- [x] Buoyancy from flooding; crush depth; sub lost → debrief
- [ ] Played by hand against the escort (balance: how lethal, how long a hunt lasts)

## M2.5 — Learnable and playable together
- [x] Training patrol: a shared step-by-step checklist with markers, scripted target and escort
- [x] Packaged for other players: pack published to the NAS drop, `sub-of-seas` launcher in nixos-config, build check on join
- [ ] First two-player session with Blaney (then tune M2 from it)

## M3 — Survival systems
- [x] Battery vs diesel (surface charging), engine station
- [ ] O2 / CO2, scrubbers, knockouts and wake-up
- [ ] Ballast/trim station, emergency blow, air banks
- [ ] System breakdowns + spare parts
- [ ] Simplified TDC: stadimeter, marks, solution quality, gyro angle to tube panel
- [ ] Nav/plot table

## M4 — Fleet and missions
- [ ] All ship classes with distinct behaviour (carrier, battleship, cruiser, kaibokan, sub-chaser, tanker)
- [ ] Formations: convoy, task force, hunter-killer group
- [ ] Mission data + mission select; objectives; tonnage scoring; debrief screen

## M5 — Three subs
- [ ] S-boat interior + control-room cluster
- [ ] Narwhal interior
- [ ] Per-size role suggestions in lobby; balance pass per crew size

## M6 — Look and feel
- [ ] Procedural textures (steel, brass, paint, rust, wood) and toon-ish lighting
- [ ] Ocean shader polish: foam, wakes, underwater fog
- [ ] Crew models (stylised, procedural animation)
- [ ] Audio: sonar pings, hull creaks, depth-charge booms, alarms, engine hum, water
- [ ] Hit feedback: shake, light flicker, sparks, debris

## M7 — Sandbox and extras
- [ ] Open-ocean patrol mode with roaming groups
- [ ] Carrier patrol aircraft
- [ ] Weather, night, thermocline layer
- [ ] Persistent crew progression / cosmetics
- [ ] Optional in-game proximity voice
- [ ] Builds for friends (needs Godot export templates in nixos-config)
