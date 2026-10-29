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
  just under the surface the scope sees murky green.
- **Crew:** Peak-like sailors: big round head, white Dixie-cup hat, dot eyes, chambray shirt
  in the crewman's own colour, navy dungarees, black boots; arms and legs swing as they walk,
  arms reach forward at a station.
- **Sound:** synthesised, not sampled (`tools/make_sounds.sh`): clean 1.5 kHz sonar ping,
  harsh metallic echo-ranging when they find us, booms that roll, groaning creaks that come
  more often deeper, an "ah-OO-gah" klaxon on opening the vents, alarm bell on a close one,
  diesel chug, motor whine rising with speed, hissing leaks, crackling fires.
- **Hits:** camera shake, lights stutter, paint flakes shake down from the deckhead.
- **UI:** typewriter / stencil feel, cream on dark panels, minimal HUD (crosshair, carried
  tool, interaction prompt).

## Direction log

| Date | Who | Direction |
|---|---|---|
| 2026-10-28 | lando | Simple art style like Peak to start; add textures later to move toward Sea of Thieves. |
