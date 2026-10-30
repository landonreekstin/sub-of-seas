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

## M8 — Blaney's list (2026-10-29)
Added by Blaney after playing. In his words where it matters.
- [x] **Pause menu**: Esc brings up a menu (resume, settings, leave to main menu). The boat
      keeps going while it is open when others are aboard; it only truly pauses in single player.
- [x] **Fix the helm wheel**: it turns on the wrong axis. It should spin around its own
      axle, like a car's steering wheel, when the rudder moves.
- [x] **Tutorial: tell you to leave a station**: when the next step is somewhere else,
      prompt "press Q to leave the station" before sending you on.
- [ ] **A more nimble boat**: "more nimble than physically possible to a slight extent so
      that people don't get bored, but not so that we're in a rocket ship". Faster turns, dives
      and speed changes than the real thing, still heavy and submarine-like.
- [ ] **Portholes**: some windows to look out of from inside the boat.
- [ ] **Frutiger Aero coral reef**: shallow, bright, clear water with coral, fish and sea
      floor terrain to look at through the portholes and periscope, "almost like you'd see
      on a nostalgic soap pump bottle at school".
- [ ] **Tutorials per crew position**: the one 29-step training patrol is too long. Split it
      so you pick the position you want to play (helm, dive, periscope/TDC, sonar, torpedoes,
      engine/air, damage control...) and do a short tutorial just for that. Each one includes
      the information you would normally hear from the other players aboard (e.g. "Captain:
      come to 090", "Sonar: contact bearing 270") so it works alone.
## M9 — Lando's list (2026-10-30)
Added by lando. Direction: **more arcadey, not strict realism**. Every existing mechanic
stays for now, until they have been tried with others.
- [x] **Settings menu**: audio (master / music / effects / voice volumes), graphics
      (resolution, window mode, quality, field of view), controls (mouse sensitivity, invert
      Y, key rebinding). Reachable from the main menu and the pause menu (M8).
- [ ] **Keep pushing the art toward Sea of Thieves**, and a bit more detailed than now:
      hand-painted colour variation, stronger toon banding, more props and detail.
- [ ] **Customisable characters that look like Sea of Thieves crew**: stylised, exaggerated
      proportions, with faces, hair, body shape, clothes and hats to choose from (builds on the
      M7 rank hats).
- [x] **Visible torpedo trails**: a bubble wake you can see from the periscope from launch
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
- [ ] **Music**: a soundtrack (menu, patrol, combat / being hunted), with its own volume in
      the settings menu.
- [ ] **Third-person emotes**: the camera pulls out to third person while you play an emote
      (wave, salute, dance, ...) so you can see your own crewman.
- [ ] **Rec room**: a compartment for whimsical fun and mini games, separate from the
      mission objectives. Matters most in the generative free-roam mode.
- [ ] **Modes on an arcade ↔ realism scale**: more modes and boats that set how arcadey or
      realistic it plays, from the arcade mode above up to a most-realistic mode. Includes the
      nuclear era, e.g. a full Typhoon-class boat with its exact deck layout as the most
      realistic.
- [x] **Sound effects for everything**: every control, station and action makes a sound. To
      start: a telegraph ding when the ordered speed changes, and the helm wheel and rudder
      gear sound as it turns. *(Every station, door, tool, footstep and ladder now has one;
      anything new gets its sound when it is made.)*
- [ ] **Optional bot crew**: AI crewmen you assign to stations and either give orders to or
      leave to act on their own, to fill out a small crew.
