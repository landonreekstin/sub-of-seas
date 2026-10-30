# Look and feel

Read this before any visible change. Log every look-and-feel direction in the direction log
and update "Current style" in the same commit.

## Current style

- **Phase 1 (now): Peak-like.** Low-poly, chunky shapes built from primitives, flat
  colours, soft lighting, no textures. Crew are capsules with a simple head, cap and face.
- **Phase 2 (M6, started): toward Sea of Thieves.** Now in: every palette colour carries a
  grey detail map (`Build.DETAIL`), mapped triplanar so the flat colour stays the colour:
  riveted painted steel panels with rust drips and chips on walls and deckhead, diamond-tread
  deck plates, brushed brass, plank wood, ship plating with strakes. Light wraps softly
  (Lambert wrap) with a faint rim light. Still to come for the full SoT feel: hand-painted
  colour variation, stronger toon banding.
- **Planned for Phase 2:** Hand-painted feel via procedural textures
  (riveted steel, brass, painted pipes, chipped paint, rust streaks, wood decking), toon-ish
  shading with soft rim light, stylised ocean with foam and big readable waves.
- **Interior palette:** pale institutional green walls (`#9DB59A`), grey-green deck
  (`#5E6B5C`), brass fittings (`#C9A04A`), red valve wheels (`#B23A2E`), black gauge faces
  with cream numerals, warm incandescent lights (`#FFD9A0`). Red "rig for red" lighting when
  submerged at night / battle stations.
- **Exterior palette:** deep Pacific blue (`#1F4E79`) to turquoise shallows, warm sky, IJN
  ships in dark grey (`#5A5F66`), wooden-deck tan.
- **Readability:** water in compartments is clearly blue and wavy, fire is bright orange with
  glow, broken gear sparks, leaks spray white. Station screens are big and legible.
- **Power you can see:** interior lights brown out as the battery nears flat (unless the
  diesels carry the load); diesel cylinder heads shake while running; panel lamps are green
  for running, blinking amber while cranking, dark when stopped.
- **Air you can see:** smoke is a grey haze hanging under the deckhead that thickens downward;
  bad air closes the screen in with a dark vignette, passing out is a black screen. The
  ballast board's "Christmas tree" lights are red for flooded tanks or open vents, green dry.
  Broken gear sparks under a red BROKEN sign; gear that needs spare parts reads WRECKED.
- **TDC:** a grey cabinet with a black face: SPEED / COURSE / GYRO in big cream numerals,
  a quality bar under them that runs red → amber → green.
- **Chart:** cream paper, pale blue-grey 1 km grid, pencil-grey own track and boat, red for
  the TDC, blue for sonar bearings. Hand-plotted, not a radar screen.
- **Enemy ships:** primitive hulls with a pointed prism bow, grey (`#4A4E55`) with a red
  boot-top, tan decks, light grey upperworks, black funnel caps and gun barrels. Each class
  has one read-at-a-glance silhouette feature: the battleship's stacked pagoda, the cruiser's
  raked trunked funnel and big bridge, the carrier's flat deck and starboard island, the
  tanker's long low well deck. A hit tanker (and any ship going down) burns orange under a
  column of black smoke.
- **Compartments:** each reads at a glance. Officers' country: bunks to port, a wardroom
  table with a cream cloth, brass-handled battery-well hatches underfoot. Crew's mess: two
  tiers of bunks both sides and a mess table. Maneuvering: dark switch cubicles with brass
  handles. Torpedo rooms: olive torpedoes racked low, bunks over them.
- **Sea:** noise-broken foam on the crests, white wakes astern of ships and a bow wave;
  just under the surface the scope sees murky green (to change: lando wants the water well
  lit like Sea of Thieves, M9).
- **Crew:** Peak-like sailors: big round head, white Dixie-cup hat, dot eyes, chambray shirt
  in the crewman's own colour, navy dungarees, black boots; arms and legs swing as they walk,
  arms reach forward at a station.
- **Sound:** synthesised, not sampled (`tools/make_sounds.sh`): clean 1.5 kHz sonar ping,
  harsh metallic echo-ranging when they find us, booms that roll, groaning creaks that come
  more often deeper, an "ah-OO-gah" klaxon on opening the vents, alarm bell on a close one,
  diesel chug, a soft airy motor whirr from aft (barely there slow, louder flat out, never a
  low droning hum), hissing leaks, crackling fires. **Everything makes a sound** (lando): every
  control, station and action, and anything new gets one when it is made. Controls sound from
  where they are, for the whole crew, whoever worked them: a two-note telegraph ding on each
  speed order, gear clicks while the helm and planes wheels spin over (they turn to the order,
  not snap), heavy lever clunks, small dial clicks, a roar of air when the vents open and a hard
  hiss while blowing, a hydraulic whine as the periscope moves, a gurgling rush flooding a tube,
  a deep clang for doors and outer doors, a chain rattle for a reload, a diesel turning over and
  catching, pencil on the chart, boots on the steel deck, a clang per ladder rung, a clink
  picking up or putting down a tool.
- **Menus:** the same dark panel with a brass border and cream type as the station screens.
  Esc pauses (Blaney): resume, settings, leave to the main menu; the boat carries on while
  others are aboard and only truly pauses for a host alone. Q leaves a station. Settings
  (lando) has audio, graphics and controls tabs, reachable from the main menu and the pause
  menu, and applies each change as you make it.
- **Hits:** camera shake, lights stutter, paint flakes shake down from the deckhead.
- **Night:** a deep blue-black sky, cold dim moonlight, black water with silver foam; inside,
  submerged, the boat rigs for red (`#FF4A35` light). Rough seas are big rolling waves.
- **Aircraft:** low-wing carrier planes, green-grey with red roundels.
- **Hats by rank:** white Dixie cup (Seaman), navy watch cap, ball cap, officer's peaked
  cap with a brass badge, and a salt-stained grey skipper's cap for a Commander.
- **Planned (Blaney's list, M8):** the boat handles a bit more nimbly than a real one, but
  never like a rocket ship; portholes to look out of; bright, shallow Frutiger Aero coral
  reefs (glossy, cheerful, aqua and green, like a nostalgic school soap-pump bottle) with fish
  and sea-floor terrain.
- **Planned (lando's list, M9):** an arcade feel over strict realism (all current mechanics
  stay until tried with others); art pushed on toward Sea of Thieves and a bit more detailed;
  customisable Sea of Thieves-style crew; torpedoes leave a visible bubble trail; portholes
  that show the water and nearby hulls; bright, well-lit water like Sea of Thieves; reefs,
  undersea mountains and shelves; sharks, whales, octopus and fish; music (menu, patrol,
  combat); emotes seen in third person; a rec room for whimsical fun and mini games.
- **UI:** typewriter / stencil feel, cream on dark panels, minimal HUD (crosshair, carried
  tool, interaction prompt).

## Direction log

| Date | Who | Direction |
|---|---|---|
| 2026-10-28 | lando | Simple art style like Peak to start; add textures later to move toward Sea of Thieves. |
| 2026-10-29 | Blaney | The sub should be more nimble than physically possible, to a slight extent, so people don't get bored, but not so that we're just in a rocket ship. |
| 2026-10-29 | Blaney | Add some portholes. |
| 2026-10-29 | Blaney | Add a Frutiger Aero themed coral reef (almost like you'd see on a nostalgic soap pump bottle at school) so we can view fish and the terrain in shallow, bright waters. |
| 2026-10-29 | Blaney | The helm wheel is not rotating on the correct axis. |
| 2026-10-30 | lando | Make the game more arcadey; it doesn't need to be strict realism. Keep all the existing mechanics for now until they have been tried with others. |
| 2026-10-30 | lando | Keep improving the graphics and art until it looks like Sea of Thieves, and a bit more detailed. |
| 2026-10-30 | lando | Characters should be customisable and look like Sea of Thieves characters. |
| 2026-10-30 | lando | You should be able to see the torpedo trails when they fire. |
| 2026-10-30 | lando | Portholes on the sides of the sub you can see out of, showing the water and ships' hulls in that direction. |
| 2026-10-30 | lando | The water should be fairly well lit, like Sea of Thieves. |
| 2026-10-30 | lando | Add music. |
| 2026-10-30 | lando | Add third-person emotes. |
| 2026-10-30 | lando | Add a rec room for whimsical fun and mini games, separate from the main objective. |
| 2026-10-30 | lando | Besides the arcade mode, add modes and submarines that vary from arcade to realism, into the nuclear era; the most realistic, e.g., a full Typhoon-class boat with its exact deck layout. |
| 2026-10-30 | Blaney | The low hum is horrible. (Asked: it is the electric motor; he chose a soft whirr instead.) |
| 2026-10-30 | lando | There should be ding sounds when you change the sub's speed, and sound effects for turning the helm. Everything should have sound effects. |
