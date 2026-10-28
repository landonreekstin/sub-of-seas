# What Claude can build alone, and what needs lando

## Claude can do end to end
- All game code (GDScript): networking, ocean simulation, AI, damage model, stations, UI.
- Meshes built in code or scenes from primitives / CSG / `ArrayMesh` (ships, interior, props,
  stylised crew). No Blender needed for the Peak-like phase.
- Shaders: ocean waves, compartment water, fire, periscope lens, toon lighting.
- Procedural textures with ImageMagick / numpy (noise-based steel, rust, paint, wood).
- Synthesised sound effects with sox (sonar ping, creaks, booms, alarms, engine hum).
- Headless unit tests, screenshot-checked runs in a virtual display, and two-instance LAN
  tests (host + client) on this machine.

## Needs lando (or friends)
- **Fun and balance.** Claude can run the game and look at it, but only real crews can say
  whether a destroyer attack is thrilling or unfair. Expect tuning feedback rounds.
- **Real multi-machine tests** with 3–8 people (firewall, Wi-Fi latency, different PCs).
- **Builds for friends.** Godot export templates are not installed here, so `godot --export-*`
  fails. Until they are added to `~/nixos-config/modules/nixos/development/gamedev.nix`,
  friends run the project from source with Godot 4.7 (`godot --path sub-of-seas`). Windows
  friends will want exported `.exe` builds — that needs the templates.
- **Firewall.** The host needs UDP port 7000 open on the LAN.
- **High-fidelity art.** Sea of Thieves-level models and hand-painted textures and rigged,
  animated characters are beyond what can be made from code; the plan is a stylised look that
  gets closer over time. Bought/free asset packs could be dropped in later if wanted.
- **Voice.** Use Discord to start. In-game proximity voice is possible in Godot but fiddly
  and hard to test alone; it's an optional late milestone.
