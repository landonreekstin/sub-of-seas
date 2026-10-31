# Look and feel

Read this before any visible change. Log every look-and-feel direction in the direction log
and update "Current style" in the same commit.

## Current style

- **Phase 1 (now): Peak-like.** Low-poly, chunky shapes built from primitives, flat
  colours, soft lighting, no textures. Crew are capsules with a simple head, cap and face.
- **Phase 2 (M6, started): toward Sea of Thieves.** Now in: every palette colour carries a
  grey detail map (`Build.DETAIL`), mapped triplanar so the flat colour stays the colour:
  riveted painted steel panels with rust drips and chips on walls and deckhead, diamond-tread
  deck plates, brushed brass, plank wood, ship plating with strakes. Every opaque piece is
  drawn by one painted toon shader (`world/toon.gdshader`, lando: keep going toward Sea of
  Thieves): soft-edged light bands (shadow, mid, lit) and the lamps' falloff in soft steps so
  light lies in pools; big soft blotches of lighter and darker paint drifting warm and cool,
  and each plate a touch different from its neighbour (soft and large on ship hulls, finer
  inside the boat); a warm rim on the lit side; a small hard highlight on brass. Glowing and
  see-through things stay plain.
- **Shapes** (lando: improve the shapes and textures of everything): nothing has a knife
  edge. Boxes are bevelled (a hair on a card, a hand's width on a ship's bridge) so every edge
  catches the toon light; cylinders are lathed with chamfered rims. Inside, the hull curves
  over at the shoulders into the deckhead and down at the bilges, with ring frames following
  the curve, so a compartment reads as the inside of a pressure hull. The textures carry
  relief: each detail map has a height map, and the toon shader bends the light with it and
  darkens the hollows, so seams sink and rivet rows, deck tread, plank joints and lapped ship
  strakes stand up. Every colour without its own map gets a fine painted grain; the crew's
  shirts and dungarees are woven cloth.
- **Sky:** painted toon clouds, flat white tops and blue-grey bellies with crisp edges,
  drifting slowly; few on a calm day, overcast in a rough sea; a soft round sun; stars on a
  night sky; no clouds under the water.
- **Sprint:** hold Shift running forward: 1.75× walking speed, the view widens a few degrees
  and the head bobs, boots ring louder and further apart (crewmates hear it). Not while
  crouched; foul air takes it away.
- **Detail inside the boat:** ring frames over the deckhead and down the shoulders with
  stencilled frame numbers, cable runs (black, red, blue) in brass clamps, red handwheel
  valves on the white pipe runs, wire cages round the bulbs, a red extinguisher by each
  after door; a coffee urn, mugs and a menu board in the mess, books over the wardroom table,
  a brass clock in the control room.
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
- **Enemy ships:** lofted hulls: a fine bow with flare and a raked stem, sheer rising to the
  bow, round bilges, a rounded stern with a transom, raised forecastles and poops; grey
  (`#4A4E55`) with the red bottom showing a hand's width above the water and a dark rubbing
  strake under the deck edge, tan decks, turrets on round barbettes with sloped faces and
  tapered barrels, funnels with a lip and black cap, deckhouses with a dark window band and an
  overhanging roof, pole masts with a yard, white ship's boats, portholes amidships, light grey upperworks, black funnel caps and gun barrels. Each class
  has one read-at-a-glance silhouette feature: the battleship's stacked pagoda, the cruiser's
  raked trunked funnel and big bridge, the carrier's flat deck and starboard island, the
  tanker's long low well deck. A hit tanker (and any ship going down) burns orange under a
  column of black smoke.
- **Compartments:** each reads at a glance. Officers' country: bunks to port, a wardroom
  table with a cream cloth, brass-handled battery-well hatches underfoot. Crew's mess: two
  tiers of bunks both sides and a mess table. Maneuvering: dark switch cubicles with brass
  handles. Torpedo rooms: olive Mark 14s racked low in cradle straps (grey warhead, tapering
  tail, four fins, twin brass screws), bunks over them.
- **Sea** (lando: do the ocean): five overlapping waves with small ripples bending the light;
  the crests glow turquoise where the light comes through them; lacy cellular foam spreading
  down the faces of the bigger waves and in faint patches on the flats; the sun's glint as hard
  bright flecks; soft toon bands on the swell. Noise-broken foam on the crests, white wakes astern of ships and a bow wave;
  a torpedo leaves a thin white bubble track from the tube to where it is, brightest at the
  head, breaking up and spreading behind and gone about a minute later (lando);
  the open water a brighter teal toward Sea of Thieves. Under the surface it is clear and well
  lit like Sea of Thieves (lando): bright turquoise, light from above and deeper blue below,
  about 60 m of visibility, darkening slowly with depth and at night, and the surface overhead
  a glowing, rippling ceiling with wakes showing white.
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
  catching, pencil on the chart, boots on the steel deck (a soft heel and gritty scuff
  with a faint plate ring, no low thud: Blaney found the first version sounded like knocking
  on his door; your own steps are quieter than a crewmate's), a clang per ladder rung, a clink
  picking up or putting down a tool.
- **Handling** (Blaney): livelier than the real boat but still heavy and submarine-like, not a
  rocket ship. Speed changes are twice as quick, turns 1.6× and dives 1.5× (a Gato: 0 to 9 kn
  in about 15 s, a full circle in about 75 s, periscope depth to 45 m in about 28 s).
  That is **Arcade**, the default. The host can pick **Standard** or **Realistic** under the
  boat on the menu (lando: modes on an arcade ↔ realism scale): Standard is half way to the
  real boat, Realistic is the real boat's figures, with more dud torpedoes (one in four, the
  1942 Mark 14), leaks and fires that get away faster, air that fouls faster and sharper
  escorts. The level shows after the patrol name, top right, and on the debrief.
- **Menus:** the same dark panel with a brass border and cream type as the station screens.
  Esc pauses (Blaney): resume, settings, leave to the main menu; the boat carries on while
  others are aboard and only truly pauses for a host alone. Q leaves a station. Settings
  (lando) has audio, graphics and controls tabs, reachable from the main menu and the pause
  menu, and applies each change as you make it.
- **Portholes:** round brass rims with eight bolts, in officers' country (over the wardroom
  table and the bunks) and either side of the mess table. Dark glass until you are close and
  looking at one; then it shows the water outside from that spot on the hull, the way you're
  looking through it, with a soft dark edge and a glint.
- **Sea life** (lando: do the sea life): smooth streamlined bodies, dark back over a pale
  belly, flat fins. Fish are deep-bodied with a dorsal fin, forked tail and a dark eye, tinted
  by their school's colour. Sharks have a tall dorsal, swept pectorals, gill slits and a big
  upper tail lobe. Humpbacks have throat grooves, knobs on the head, a small dorsal hump and
  very long white flippers. Chunky fish in bright schools (yellow, sky blue, orange, mint, pink),
  more of them over a reef; grey sharks with white bellies circling now and then; orange
  octopus on a shallow bottom; humpbacks (dark slate, pale belly, long white flippers) that
  blow a spout at the surface. Coral on the island reefs is Blaney's Frutiger Aero look:
  glossy candy-coloured brain coral, staghorn and sea fans, with bubbles rising.
- **Faces** (lando: do the faces): a round head on a chunky jaw; big eyes (white, dark iris,
  a glint) under heavy lids and brows; rosy cheeks; a bulbous nose with a bridge; a crooked
  smile and a lower lip; ears with a fold. Skin is a soft painted texture with no blotches;
  hair, brows and beards have strands.
- **Crewmen** (lando: customisable, like Sea of Thieves crew): stylised and exaggerated, big
  forearms and hands, chunky boots, a sailor's collar and neckerchief, a big nose, ears and
  heavy brows. Pick build (average, wiry, stocky, barrel-chested), six skin tones, hair (seven
  styles, seven colours), beard (seven), an extra (eyepatch, gold earring, scar, pipe,
  bandana), the rank hats and a shirt colour, in "Your sailor..." on the main menu.
- **Bot crewmen:** look like any crewman (random build, face and shirt, a navy watch cap),
  standing their station with hands on the gear and a name tag with their job ("Sparks
  (planesman)", "— on orders" when following yours). They speak through the same announcements
  as everything else: "Stubby (sonar): contact bearing 270, warship, turns for 20 knots."
- **Bilge pump:** a grey-green panel low on the control room's forward bulkhead with a blue
  ribbed motor, a suction pipe into the bilge, a red switch and a green lamp; it shakes and
  whirrs while it pumps.
- **Crouch:** hold Ctrl: your eye drops to 1.05 m, you move at half speed and your boots are
  near silent; crewmates see you squat down.
- **Emotes:** 1 wave, 2 salute, 3 jig, 4 point, 5 cheer. The camera swings out in front, a
  little to one side wherever the hull has room, so you see yourself; moving ends it.
- **Rec room** (games picked by Claude while lando was away; add more): between the mess and
  the engine room on the Gato and Narwhal. A dartboard on the starboard wall (real rings and
  scoring, a swaying aim, three darts a turn, best turns chalked up and called out to the
  crew), a jukebox with an amber glow that the room hears (the shanty, the slow watch), a
  green-baize card table, a porthole.
- **Music** (synthesised, `tools/make_music.py`; style picked by Claude while lando was away,
  to match the Sea of Thieves direction; change it freely): the menu is an original D-minor
  sea shanty on a two-reed accordion with oom-pah bass and stomp-clap; a patrol is a calm,
  sparse pad with a lonely flute; being hunted (an escort hunting within 6 km, charges in
  the water) brings in a heartbeat pulse under trembling strings, holding 20 s after; the
  debrief plays a short accordion fanfare for a completed patrol, a falling minor line for a
  lost boat.
- **Hydrophones:** the operator hears contacts in the headphones: merchant screws slow and
  heavy, warships fast and light, capital ships a deep four-shaft churn, whales a long moaning
  song, snapping shrimp over a reef, the sea's hiss under it all.
- **Islands** (lando: do the islands): the ground carries a rock texture with strata and
  cracks, and the greens vary patch to patch. The jungle is thick with round, lumpy canopy
  trees in four greens, so it reads as forest through the periscope. Palms have curving
  ringed trunks, drooping two-part fronds and coconuts. Grey boulders sit on the beaches and
  slopes, a few awash. Low-poly and flat-shaded like everything else: bare rock peaks, deep jungle,
  green scrub, a pale sand beach with a few leaning palms, then a reef of sand and coral
  (pink, orange, violet) and blue-grey slopes into the deep. Light haze so they read 10 km off.
- **Chart:** land in buff, reefs (under 12 m) blue, shallows (under 100 m) pale blue, the least
  depth over seamounts and shelves as a blue sounding, and each marked target as a red
  diamond at its last marked position with how long ago (grey once sunk).
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
  customisable Sea of Thieves-style crew; portholes
  that show the water and nearby hulls; reefs,
  undersea mountains and shelves; sharks, whales, octopus and fish; music (menu, patrol,
  combat); emotes seen in third person; a rec room for whimsical fun and mini games.
- **Training crew calls (Blaney):** in the short per-job courses, the crewmates you would
  hear are played for you: a big line near the top, the speaker in brass caps and the words
  in cream quotes ("CAPTAIN: \"Come to course zero-niner-zero.\""), with a short bell like an
  order over the boat's speakers. Training opens on a list of jobs to pick from; the long
  whole-boat course stays at the bottom.
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
| 2026-10-30 | Blaney | The footsteps make it sound like someone is knocking on my door, which is not optimal. |
| 2026-10-30 | Blaney | Tutorials per job: pick the job from a list when you click Training patrol; crew calls show as a big line with who said it and a little bell; keep the long whole-boat training at the bottom of the list. |
| 2026-10-30 | lando | I want to greatly improve the graphics. Improve the shapes and textures of everything. Also add a sprint functionality. |
| 2026-10-30 | lando | (on the graphics pass) I like it. You can merge, and do the faces, the ocean, the islands or the sea life. |
