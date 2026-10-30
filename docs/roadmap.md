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
- [x] O2 / CO2, scrubbers, knockouts and wake-up
- [x] Ballast/trim station, emergency blow, air banks
- [x] System breakdowns + spare parts
- [x] Simplified TDC: stadimeter, marks, solution quality, gyro angle to tube panel
- [x] Nav/plot table

## M4 — Fleet and missions
- [x] All ship classes with distinct behaviour (carrier, battleship, cruiser, kaibokan, sub-chaser, tanker)
- [x] Formations: convoy, task force, hunter-killer group
- [x] Mission data + mission select; objectives; tonnage scoring; debrief screen

## M5 — Three subs
- [x] S-boat interior + control-room cluster
- [x] Narwhal interior
- [x] Per-size role suggestions in lobby; balance pass per crew size (first pass: CO2 and reload time scale with crew; tune by playing)

## M6 — Look and feel
- [x] Procedural textures (steel, brass, paint, rust, wood) and toon-ish lighting
- [x] Ocean shader polish: foam, wakes, underwater fog
- [x] Crew models (stylised, procedural animation)
- [x] Audio: sonar pings, hull creaks, depth-charge booms, alarms, engine hum, water
- [x] Hit feedback: shake, light flicker, sparks, debris

## M7 — Sandbox and extras
- [x] Open-ocean patrol mode with roaming groups
- [x] Carrier patrol aircraft
- [x] Weather, night, thermocline layer
- [x] Persistent crew progression / cosmetics
- [x] Optional in-game proximity voice (push to talk: Caps Lock; checked end to end with a test tone, not yet with a real microphone)
- [ ] Builds for friends (needs Godot export templates in nixos-config). Linux friends on the homelab are covered by the published pack and the launcher (M2.5); Windows `.exe` builds still need the templates

## M9 — Lando's list (2026-10-30)
Added by lando. Direction: **more arcadey, not strict realism**. Every existing mechanic
stays for now, until they have been tried with others.
- [ ] **Settings menu**: audio (master / music / effects / voice volumes), graphics
      (resolution, window mode, quality, field of view), controls (mouse sensitivity, invert
      Y, key rebinding). Reachable from the main menu and the pause menu (M8).
- [ ] **Keep pushing the art toward Sea of Thieves**, and a bit more detailed than now:
      hand-painted colour variation, stronger toon banding, more props and detail.
- [ ] **Customisable characters that look like Sea of Thieves crew**: stylised, exaggerated
      proportions, with faces, hair, body shape, clothes and hats to choose from (builds on the
      M7 rank hats).
- [ ] **Visible torpedo trails**: a bubble wake you can see from the periscope from launch
      to hit or miss.
- [ ] **Navigation station**: a chart with each target at its last marked position and the
      land masses drawn in (builds on the M3 chart table).
- [ ] **Islands and land masses** in the ocean world, which the boat has to steer around.
- [ ] **Portholes** along the sides of the boat, showing the water and any ship hull on that
      side (overlaps Blaney's M8 portholes).
- [ ] **Well-lit water like Sea of Thieves**: bright, clear and readable under the surface,
      not murky.
- [ ] **Sea floor with reefs and mountains / shelves** the boat has to avoid (running into
      them damages it); pairs with Blaney's M8 coral reef.
- [ ] **Sea life**: fish, sharks, whales and octopus. Whales show up on sonar as false
      contacts.
- [ ] **Listening station**: hydrophone headphones where you hear ship engines and screws
      and animal sounds, and have to tell them apart.
