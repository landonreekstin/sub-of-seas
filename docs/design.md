# Sub of Seas — Game Design

"Sea of Thieves in a WWII submarine." A first-person co-op PvE game for 3–8 friends on a
LAN. The crew never leaves the boat. They hunt Imperial Japanese Navy surface ships in the
Pacific, 1942–44, and survive being hunted back. Fun comes from crew coordination: no one
person can find, aim, fire and survive alone.

Everything here is a starting point. Numbers live in `data/*.tres` and get tuned by playing.

## 1. Session loop (patrol missions)

1. **Lobby.** Host picks a sub (sized to the crew) and a patrol mission. Friends join by IP.
2. **Transit.** Start surfaced on diesels, charging batteries. Lookout through the periscope /
   bridge view, navigator plots a course to the patrol area.
3. **Contact.** Sonar hears screws, or the periscope spots smoke. Identify: freighter? convoy
   with escorts? battleship task force?
4. **Approach.** Dive, close submerged on battery. Too fast = noisy and battery drains; too slow
   = target gets away. Periscope up = risk of being seen.
5. **Attack.** Periscope marks target; TDC turns that into a gyro angle; captain calls
   "Fire one!"; torpedo room fires. Torpedoes run, hit (or dud, or miss).
6. **Evasion.** Escorts charge in. Go deep, run silent, turn away. Depth charges cause leaks,
   fires, broken systems. Crew scrambles with tools; doors get shut.
7. **Recover.** Surface when clear, ventilate, recharge, repair.
8. **End.** Mission ends when objectives are met and the sub leaves the area, or the sub is lost.
   Debrief: tonnage sunk, ships by class, damage taken, crew stats.

Lose conditions: hull crushed (below crush depth), sub floods past recovery, everyone passes
out (CO2). There is no respawn mid-mission for the sub; a player knocked out by fire/smoke/CO2
wakes up after a short time in the nearest safe compartment (like SoT ghost ship), so nobody
sits out.

## 2. The three subs

Bigger crew → bigger boat → more stations spread over more space, so every player is needed.

| | **S-boat** (small) | **Gato-class** (medium) | **Narwhal-class** (large) |
|---|---|---|---|
| Crew | 3–4 | 4–6 | 6–8 |
| Tubes | 4 bow | 6 bow, 4 stern | 6 bow, 4 stern |
| Torpedoes carried | 12 | 24 | 40 |
| Surface / sub speed | 14 / 11 kn | 20 / 9 kn | 17 / 8 kn |
| Test / crush depth | 60 / 90 m | 90 / 150 m | 90 / 140 m |
| Dive time | 35 s | 30 s | 60 s |
| Battery endurance (slow) | short | medium | long |
| Hull compartments | 4 | 7 | 8 |
| Character | Fragile and cramped; control-room cluster lets 1 person run helm + periscope + sonar | The all-rounder; dedicated sonar room, two torpedo rooms far apart | Huge, slow to dive, big target, lots of ammo and endurance; long runs between stations |

Compartments (Gato, fore→aft): Forward Torpedo Room · Officers/Battery (lower deck: battery
well) · Control Room (lower: pump room) + Conning Tower above (periscope, TDC, helm) ·
Crew/Galley · Forward Engine Room · After Engine Room · Maneuvering (electrical) · After
Torpedo Room. Levels: main deck, conning tower (ladder up), pump room / battery well
(hatch down).

### Role splits

Roles are suggestions shown in the lobby, not locks. Anyone can use any station.

- **S-boat (3–4):** *Captain/Conn* (helm + periscope + sonar cluster), *Torpedoman*
  (load and fire 4 bow tubes), *Engineer* (dive/ballast, engine, repairs), optional *Repair*.
- **Gato (4–6):** *Captain* (periscope + TDC in the conning tower), *Helm/Dive* (control room),
  *Sonar/Nav*, *Fwd Torpedoman*, *Aft Torpedoman / Engineer*, *Damage Control*.
- **Narwhal (6–8):** adds a dedicated *Navigator*, second *Damage Control*, and an
  *Electrician* (battery/motors are spread out and break more).

## 3. Stations

Interacting with a station (`E`) locks movement and moves the camera to a fixed view of
that equipment. `Esc`/`Q` leaves. Stations in a **cluster** (helm, periscope, sonar in the
S-boat control room; periscope + TDC in the Gato conning tower) switch with `Tab` without
leaving station mode. One player per station; others see who is on it.

| Station | Does | Notes |
|---|---|---|
| Helm | Rudder angle, engine telegraph (All Stop → Flank, Astern) | Speed sets noise, battery drain |
| Dive planes | Ordered depth, plane angle | Holds depth automatically once trimmed |
| Ballast / trim | Flood/blow main ballast, trim tanks, emergency blow | Emergency blow uses air banks; high-pressure air is finite |
| Periscope | Raise/lower, rotate, zoom, stadimeter range, "Mark" target | Raised scope above ~1 kn leaves a feather; raised long = spotted |
| TDC | Takes marks → computes gyro angle and "solution quality" | Captain or a 2nd officer; speed/AoB estimates can be adjusted |
| Sonar | Passive: bearings of contacts by sound, class guess by screws. Active ping: range, but alerts everyone | Hears depth charges hit the water (warning!) |
| Nav / plot | Chart with own track, marked contacts, mission area | Draw/mark for the team |
| Torpedo tube | Load (hoist torpedo from rack, ram), flood tube, open outer door, fire | Reload takes ~45 s of hands-on work; 2 people faster |
| Engine (diesel) | Start/stop, charges battery when surfaced | Can't run submerged; breaks under damage |
| Electrical | Battery charge, motor switchboard, lights | Battery damaged + seawater = chlorine gas (M3+) |
| Air | O2 bleed, CO2 scrubbers (absorbent canisters) | Submerged CO2 rises with crew count and time |

## 4. Damage, repair and tools

Every compartment tracks: **water level** (0–1), **fire** (0–1), **air** (O2, CO2, smoke),
and its **systems** (each with health 0–100).

- **Hits** (depth charges, shell fire when surfaced, collisions) roll damage per compartment by
  distance: leaks (hull breaches with a flow rate), fires (near electrical/engines), system
  damage, lights out, people knocked over.
- **Leaks**: fix with the **welding torch** (hold on the breach; bigger leaks take longer).
- **Water**: **portable pump** (carry it, place it, it drains that compartment slowly) and the
  fixed **bilge pump** in the pump room (fast, needs power, can break).
- **Fire**: **extinguisher** (limited charges, refill at rack), or close the doors and let it
  burn out the compartment's oxygen (anyone inside passes out).
- **Broken systems**: **wrench** + a **spare-parts box** carried from stores.
- **Doors**: watertight doors between compartments. Open doors let water level equalise and
  fire/smoke spread. Closing one on a flooding compartment saves the boat — possibly with a
  friend inside. Doors take a moment to dog shut.

Players carry one tool at a time; tools live in racks and can be dropped anywhere. Total
water in the hull drives buoyancy: past a threshold the boat gets heavy, sinks without blowing
ballast, and can go past crush depth.

## 5. Enemies

All AI. Each class has a role with its real strengths and weaknesses. Details and numbers in
`docs/ships.md`.

| Class | HP | Threat to a submerged sub | Behaviour |
|---|---|---|---|
| Freighter / tanker | low–med | none | Plods along, zig-zags if alerted, radios position |
| Fleet carrier | huge | none directly | Always escorted; launches patrol planes that spot periscopes and shallow subs (M7) |
| Battleship | huge | none submerged; deadly guns if you surface | Fast (25–30 kn), zig-zags hard, escorted |
| Heavy cruiser | high | low: a few depth charges, floatplanes | Fast, leads small groups |
| Destroyer | low | **the nemesis**: sonar + big depth-charge patterns, 35 kn | Search pattern → contact → attack runs → circles back; hunts in pairs |
| Kaibokan escort | med | high: excellent sonar, lots of depth charges, slow (19 kn) | Patient, persistent, guards convoys |
| Sub-chaser / motor torpedo boat | very low | medium: light charges, very fast, great at spotting | Swarms the last known position |

**Detection model.** Each AI ship has an alert level (unaware → suspicious → hunting → attacking).
Inputs: periscope up (visual chance by range, sea state, scope speed), surfaced sub (very
visible), sub noise (speed, depth, running diesels, damage clanks) vs their hydrophones,
active sonar pings (escorts only, range + bearing when it hits, degraded by depth/speed),
torpedo wakes (reveals your bearing). Going deep and slow ("silent running") is the classic
counter, and costs time and air.

**Depth charges.** Rolled/thrown in patterns, sink at a fixed rate, detonate at their set
depth. Damage falls off with 3D distance; close = several leaks + fires, far = shake and
lights flicker. Sonar hears the splash a few seconds before.

## 6. Torpedoes (simplified TDC)

1. Periscope: put the crosshair on the target, use the **stadimeter** (match top of mast to
   waterline) to get range, press **Mark**. Two marks a few seconds apart give the TDC speed
   and heading estimates. Sonar bearings can also feed it.
2. TDC shows target range, speed, angle-on-bow and a **solution quality** bar; the operator can
   nudge estimates if they disagree (e.g. "he's doing 12 knots, not 9").
3. TDC sends the **gyro angle** to the torpedo room, where the tube panel shows "SOLUTION
   READY". Captain calls "Fire one!", torpedoman fires.
4. Mk 14 torpedoes: 46 kn, ~4 km range, small chance to run deep or dud (historically
   accurate, deliberately frustrating at low odds — tunable to 0). The wake can give the sub away.

Without a solution players can still fire straight down the bow on a gut call.

## 7. Co-op design principles

- **Information lives in one place, action in another.** The periscope sees, the torpedo room
  fires, the helm steers. Voice callouts are the glue.
- **Emergencies pull people off stations.** A depth-charge run turns an attack into a scramble.
- **Every crew size is full.** More players → bigger boat, more distance, more simultaneous jobs.
- **Readable at a glance.** Water in a room is visible, fires glow, broken gear sparks, gauges
  are big. HUD stays small; the boat is the UI.
- **Failure is funny, not punishing.** Knocked-out players come back; a lost sub ends a short
  mission, not a campaign.

## 8. Controls (keyboard + mouse first, gamepad later)

`WASD` move · mouse look · `Space` climb ladder · `Ctrl` crouch · `E` interact / use station ·
`Esc`/`Q` leave station · `Tab` next station in cluster · `LMB` use tool · `G` drop tool ·
station views use mouse + `WASD`/arrows for the dials they show on screen.

## 9. Open questions (decide by playing)

- Diesel/battery loop: is managing charge fun or a chore at this session length?
- How lethal should destroyers be in the first missions?
- Should the captain see sonar contacts on the chart automatically or only when the sonar
  operator marks them? (Leaning: only when marked — more talking.)
- Proximity voice in-game vs Discord.
