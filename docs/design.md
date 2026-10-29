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
4. **Approach.** Dive, close submerged on battery (Gato: 30 min at 1/3, ~4 min at flank; lights brown out near flat, and a flat battery stops the motors). Too fast = noisy and battery drains; too slow
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
| Engine (diesel) | Start/stop each of two diesels (1/2), battery gauge | Surfaced only: diving with them running floods them (controls broken + a leak). One diesel = 70 % surface speed, two = full; what the screws don't use charges the battery (Gato: flat to full in 8 min stopped) |
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

**How it is built (M2).** Each ship has an *awareness* 0..1 (`sim/detection.gd`): lookouts
add to it by range, scope height and scope speed (a surfaced boat is six times as visible);
hydrophones add by the sub's noise (quadratic in speed; shallow and fast cavitates) unless the
ship itself is going faster than ~14 kn. Awareness decays slowly. Merchants that spot the
scope radio it: every escort gets a rough position and the convoy zig-zags at full speed.
Escorts run a small state machine (`sim/ship_ai.gd`): **patrol** (keep station on the convoy)
→ **search** (head for the rough position at 14 kn, pinging) → **hunt** (echo contact: close
in, refine) → **attack** (sprint the last 500 m over the predicted position; the sonar is
blind this close) → **open** (roll the pattern, run out 35 s, turn and hunt again). Contacts
age; 90 s without a fix drops a hunt back to search. Course and speed of the sub are
estimated from fixes 20 s or more apart, so turning away during the run is what makes them
miss. Firing torpedoes inside lookout range gives a rough fix from the wake; our own active
ping tells every escort within 8 km where we are.

**Sonar station.** The ring shows every contact the hydrophones hear at its true bearing
(our own speed drowns them out). Training the hydrophone onto a contact classifies its screws
(merchant/warship, rough knots). `P` pings: range to everything within 6 km, but it gives the
boat away. Only the operator sees enemy echo-ranging and the splashes of a pattern going in —
call it out. Everyone hears an echo-ranging ping that finds the hull.

**Damage control (M2).** The hull state (`sim/hull.gd`) holds water per compartment, leaks
(rate, weld time), fires (grow, spread inside a room and through open doors, break stations
in that room, drown under 0.45 m of water), placed pumps and broken stations. Racks in each
compartment hold a welding torch, extinguisher, wrench and portable pump (two pumps aboard).
Hold LMB with the right tool on a leak, fire or broken station; LMB with a pump sets it
down on the deck, E picks it up again; G puts any tool down. Water in a room slows walking.
Total flooding makes the boat heavy: way on and planes hold a little, then she sinks
whatever the dive station orders. Below test depth rivets start to pop (new small leaks).
Lost when past crush depth or 65 % flooded; the debrief shows time, sinkings, charges felt,
leaks welded, fires out and repairs.

**Ballast and air (M3).** Main ballast (`SubState.ballast`) is 0 dry .. 1 flooded. Dry, she
floats; the planes can't take her under. Opening the vents floods the tanks over the class's
`flood_seconds` and she settles to decks awash (4.5 m), then the dive station takes her down.
Coming up, the planes stop at awash: blowing the tanks with high-pressure air surfaces her
(diesels need that: their induction floods below 3 m). A normal blow takes 20 s and 12 % of
the air banks; the emergency blow (X twice) takes 4 s and 35 %, and the buoyancy of dry tanks
holds up a flooding boat that would otherwise sink. The compressors refill the banks on the
diesels. Air (`sim/air.gd`): submerged, CO2 rises 0.08 %/min plus 0.04 per player (4 players:
3 % in ~12 min) and O2 falls with it. A CO2 canister scrubs 0.6 %/min for 5 min (8 aboard a
Gato); the oxygen bleed adds 0.8 %/min from a 40-minute bank. Fires make smoke in their room,
which drifts through open doors. Past 3 % CO2 / under 17 % O2 / in smoke the screen closes in
and you walk slower; at 6 % / 14 % or in thick smoke you pass out after 6 s, for 15 s, and
come round in the compartment with the best air. At 8 % / 12 % the boat is lost. Surfacing
clears everything.

**Breakdowns and spare parts (M3).** Gear driven hard wears out (wrench to fix): diesels
running (about once per 25 min each), the periscope raised at over 5 kn submerged (every
~3 min), hard rudder at flank (every ~10 min), an active ping (4 %), a torpedo firing (3 %
jams the tube). Gear caught in a close blast or flooded diesels are WRECKED: someone fetches a
spare parts box from stores (engine room; 6 on a Gato), holds LMB to fit it (3 s), then the
wrench finishes the job. A box put back in stores goes back on the count.

**Fleet and missions (M4).** Eight classes in `data/ships/` (numbers in `docs/ships.md`),
each with a `role`: merchant (freighter, tanker; tankers burn and take 2.5 hits), capital
(carrier, battleship, cruiser: fast, zig-zag hard, guns), escort (destroyer, kaibokan: slow
but a 3 km sonar, 120 charges and 2.5× the patience), chaser (sub-chaser: fast, sharp-eyed,
small charges at 0.6 power). The sonar classes screws by role. Anything with guns that knows
about a surfaced boat shells her: salvoes every few seconds, accuracy falling with range, a
hit does what a depth charge `gun_blast` metres away would (a battleship's is 4 m). Merchants
and capital ships in a formation keep station on their leader and zig-zag with it until
alerted, then scatter; escorts keep their screen spots; a hunter-killer group sweeps a box
side by side, pinging. A patrol (`data/missions/*.tres`) places groups and sets objectives
(sink tonnage / a class / a role, survive N minutes; some are bonus). It completes when the
main objectives are done and no escort has hunted nearby for a minute (or at once when it
was a survive patrol), and ends early if the targets got away (sunk or out of 25 km reach).
The debrief lists objectives, ships by class and the crew's stats.

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

**How it is built (M3).** `M` on the periscope marks the ship under the crosshair: true
bearing (±0.5°) and a stadimeter range (±3 %, ±1.5 % in high power), stamped with the time
and our position, kept in `crew.tdc` (last 8 marks on one target; marking a new ship starts
over). `sim/tdc.gd` fits a straight track through the marks by least squares once they span
30 s (one mark: 8 kn across the line of sight, a guess). The operator nudges speed (W/S) and
course (A/D). The intercept for a 46 kn torpedo from the bow gives the gyro angle; past 90°
or a 4 km run there is no solution. Quality grows with marks, their span and closeness.
`T` sends it: the bow tubes' gyros then follow the live solution until someone touches a
gyro or presses T again.

**Chart table (M3).** North up, centred on the boat: the boat's own track, TDC marks (red
crosses) and the TDC's estimate of the target's track ten minutes ahead, sonar bearings the
operator put on the plot with M (blue lines, fading over 3 minutes), and up to 16 numbered
pencil marks anyone can put down (LMB) or rub out (RMB). Contacts only appear when someone
marks them, so the chart is where the crew's information meets.

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
