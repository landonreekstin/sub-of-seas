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
- **Weather** (lando: rain and squalls): rain squalls a couple of km across drift across the
  patrol with the wind, building up and blowing through in a quarter of an hour. From outside,
  a dark lumpy cloud base with a grey curtain of rain hanging to the sea, in broad veils and
  fine streaks, dark at night. Inside one: the sky goes low and grey, the sun dims, grey rain
  fog closes the horizon in to a km or two, the sea turns dull grey-green, runs higher and is
  pocked white by drops, and rain streaks down past the eye. Rain drums on the hull near the
  surface. The lookouts call it when one comes over and when it clears.
- **Out on deck** (Blaney: get out and walk on top of the boat when she's high enough above
  the water): surfaced, look up at the bridge hatch over the gun's ladder and press E to climb
  out onto the teak casing between the fairwater and the gun; the sea, the sky and the crew on
  deck all as seen from the real boat, rolling with her, and the sound of the sea. Walk off the
  edge and you splash in and swim (head just above the water, slower), then climb back up the
  rung ladders on either side, aft of the fairwater. E at the deck hatch goes below. The boat
  can't dive while anyone is out (Blaney): the dive and vent orders are refused with "Can't
  dive: there's crew out on deck!"; if she goes under anyway, everyone on deck is sent down.
- **Wrestling on deck** (Blaney: a simplified Your Only Move Is HUSTLE, Greco-Roman moves
  only): a ring painted in white across the aft casing (two lines right across the deck and a
  centre mark). Two crewmen standing in it start a bout after a 3 s count; they lock into a
  clinch facing each other across the deck. Each turn both pick a move in secret (8 s; no pick
  braces): 1 Push, 2 Arm drag, 3 Body lock, 4 Suplex (needs a lock), 5 Brace; then both play
  out together and a line says what happened. Arm drag beats push, push beats a body lock
  attempt, a body lock beats an arm drag, a suplex from a lock throws far, an arm drag breaks a
  lock, off balance doubles how far you're driven. A panel at the bottom: the two names, the
  clinch on a SEA |----X----| SEA bar, the move keys, the last turn. Driven past your edge,
  you go over the side into the sea and swim back to a ladder.
- **Navigation room** (Blaney): a compartment just aft of the control room in every boat.
  The middle of the room is clear (the sand table was taken out, Blaney 2026-11-06: a giant
  hologram is planned there). A chart locker in the starboard after corner.
- **Outside cameras** (Blaney: a viewing centre; both a wall of small screens and a big one):
  on the port side of the navigation room, a grey console under six small screens (bow, stern,
  port, starboard, bridge, keel), all live while you're in the room, and a big screen above;
  man the console and 1-6 picks the big one. The cameras ride on our own boat: on the surface
  you see her decks and the sea, dived the blue water and the hull.
- **Ship's band** (Blaney: instruments of all types that each play a part of a shanty, like
  Sea of Thieves; a mix of modern and traditional; take one and play anywhere): a wall board
  "SHIP'S BAND — THE FOGGY DEW" in the rec room (the S-boat's in the navigation room) with
  one each of tin whistle, fiddle, concertina, bodhrán, electric guitar, bass guitar, snare
  and sticks, keytar synth. E takes one, hold LMB to play your part, G puts it back. Every
  part runs on the same clock, so each joins in time and with all eight it's the whole song.
  First song: "The Foggy Dew", the traditional air, our own arrangement in E minor at 84 bpm:
  whistle (octave up) and fiddle on the tune, concertina chords, bodhrán eighths, overdriven
  power chords, a walking bass, a rock kit, a soft synth pad and arpeggio. All real recorded
  instruments now (the whistle is a recorder, the nearest in the library), played a touch off the
  beat like people, not machines.
- **Deck gun** (lando: deck gun crewed from inside, up the conning-tower hatch, ammunition
  passed up): our boat on the surface seen from the gunlayer's seat, a black hull with a teak
  deck, the fairwater and periscope shears behind, the gun's dark barrel in the lower right of
  the view, the bow ahead. A plain ring-and-cross gunsight in the middle, the range set on it
  in a small panel at the top. Firing: a flash and a small puff of smoke at the muzzle, the
  barrel slams back, a hard crack and boom (muffled for the crew below), the view kicks. Fall
  of shot is a tall thin white splash; a hit is an orange flash and a puff of black smoke on
  her side. Inside: a ladder up to a hatch ring in the deckhead marked DECK GUN; the
  ammunition scuttle is a hatch flush in the deck with brass rounds showing down the hole.
- **Divers** (Blaney): a grey DIVING GEAR locker by the deck hatch; the suit goes with the boat's
  era (WWII: brass hard hat with a round face window and side ports, tan canvas dress; Typhoon:
  black drysuit, full mask, twin tanks; modern: scuba). The view out is framed by the helmet's
  round brass window (a mask's dark edge on the Typhoon); a lamp lights the water deep down.
  Steel grab rails either side of the bow, the fin and the after casing.
- **The cave** (Blaney): a grey-green rock ridge standing some 45 m out of the water, sheer cliffs
  down to its foot, a square-ish mouth low in each end face. Inside, an S-bend tunnel of dark rough
  rock, its roof rising and dipping and its floor humped in places, lit only by soft glowing spots
  (blue-green, sea-blue, pale green) on the walls and roof. Every boat fits, with room to spare
  only if she's held straight and level. Scrapes clang and judder the crew; the time and the
  scrapes show on the objective.
- **The Titan** (Blaney: like the real one, game controller and all): inside, one dark carbon tube
  with flat titanium ends bolted round, floor mats and five cushions, cold white LED strips, the
  viewport low in the bow end, the scrubber on the starboard wall; a little roomier than the real
  tube so the crew can stand. The pilot sits on the floor aft holding a dark grey game controller
  with coloured buttons, a black screen on the wall ahead to starboard (depth, speed, battery,
  HULL MONITOR, red when the strain passes half). Past 4,000 m the carbon cracks: sharp cracks
  louder each time, lights flicker, three warnings, then a single deep bang. No gore. Outside: a
  white fairing, black frame and skids, four black thrusters; no maker's name.
- **Things from the depths** (Blaney: creepy dread, no gore): dark shapes with eyes that catch the
  light. A dark red giant squid, a black anglerfish with needle teeth and a glowing green lure, a
  long dark green serpent with a frill and yellow eyes, a dark grey megalodon as long as a boat.
  Their call is a whale's song slowed to a groan; a grab creaks the frames, a strike thumps and
  flickers the lights.
- **Pace** (Blaney: not a waiting simulator): in arcade the boat moves, speeds up, turns and
  dives twice as fast as standard; noise and battery go by her real speed. Crewmates never block
  each other.
- **Sprint:** hold Shift running forward: 2.1× walking speed (Blaney: a bit faster, for the long walks on the bigger boats), the view widens a few degrees
  and the head bobs, footsteps a little louder and further apart (crewmates hear it). Not while
  crouched; foul air takes it away.
- **Detail inside the boat:** ring frames over the deckhead and down the shoulders with
  stencilled frame numbers, cable runs (black, red, blue) in brass clamps, red handwheel
  valves on the white pipe runs, wire cages round the bulbs, a red extinguisher by each
  after door; a coffee urn, mugs and a menu board in the mess, books over the wardroom table,
  a brass clock in the control room.
- **Lived in, but tidy** (Blaney): a galley in every boat (the Gato's and Narwhal's on the
  mess's port side, the S-boat's aft in the battery room, the Typhoon's in her mess): black iron
  range with pots steaming and a pan frying you can hear, a hood over it, maple work counter with
  loaves, a steel sink, rows of tins on shelves behind fiddle rails, ladles on a rail, and the
  cook in whites and a toque stirring. Mess and wardroom tables laid (plates, knives and forks,
  mugs, salt, pepper, ketchup, bread), cushioned benches, a cribbage board, photos and letters
  pinned over the table, the cool room and freezer hatches in the deck. Bunks: family photos,
  painted 1940s pin-ups (fully dressed; Soviet film posters on the Typhoon), letters, curtains
  drawn part way, sea bags, books, shoes under the bottom bunk, a towel on a stanchion, and two
  off-watch men asleep in each crew's quarters. Fold-down bunks over the reload torpedoes. Things
  are stowed, not strewn.
- **Full and working, the walkway clear** (Blaney): a ventilation trunk with grilles along every
  deckhead; in the control room pipe risers up all four corners and valve manifolds overhead
  either side of the walkway, their handwheels on reach rods; gauge needles tremble as she runs,
  more with the diesels going.
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
- **Arcade aiming** (Blaney): no TDC or gyros in Arcade. Torpedoes run straight out of the
  bow (or stern) at twice the Mk 14's speed. Through the periscope each ship in sight has a red
  diamond marked AIM floating over the horizon, leading a moving ship by where it will be, and
  a brass tick marked BOW below the horizon shows where the boat points. Turn her until BOW sits
  under AIM: the mark goes green and reads FIRE!, and the tubes read ON TARGET. Ships out of
  torpedo range get a grey TOO FAR mark. The TDC cabinet stands dark in Arcade and says how to
  aim. Standard and Realistic keep the TDC and the real speed.
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
- **Compartments:** each reads at a glance. Wardroom: a locker bank to port, a table with a
  cream cloth, brass-handled battery-well hatches underfoot. Crew's mess: two mess tables and a
  coffee urn. Crew's quarters (Blaney: the sleeping quarters away from the weapons and
  operation areas): the boat's only bunks, three tiers either side of an aisle, blue blankets
  and white pillows, amidships between the mess and the rec room (S-boat: aft of the
  navigation room). Maneuvering: dark switch cubicles with brass handles. Torpedo rooms: olive
  Mark 14s racked low in cradle straps (grey warhead, tapering tail, four fins, twin brass
  screws), no bunks.
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
- **Crew:** WWII US submariners at sea in ordinary human proportions (Blaney, see Crewmen):
  slim, a head in proportion, small plain features; faded chambray work shirt (only a hint of
  the crewman's own colour) with an open collar and sleeves to the elbow, belt and buckle,
  straight navy dungarees, black work boots; arms and legs swing as they walk, hands reach
  forward onto the gear at a station.
- **Sound** (Blaney: real recorded samples from free-to-use libraries; every source in
  `docs/credits.md`, `tools/make_recorded.py`): real recordings wherever one suits, a real WWII
  US Navy dive klaxon among them, each kept at the level of the synthesised sound it replaced so
  the mix stays as tuned. Our own sonar ping, harsh metallic echo-ranging when they find us, booms that roll, groaning creaks that come
  more often deeper, an "ah-OO-gah" klaxon on opening the vents, alarm bell on a close one,
  a recorded marine diesel, a soft airy motor whirr from aft (still synthesised: barely there
  slow, louder flat out, never a low droning hum), hissing leaks, crackling fires. **Everything makes a sound** (lando): every
  control, station and action, and anything new gets one when it is made. Controls sound from
  where they are, for the whole crew, whoever worked them: a two-note telegraph ding on each
  speed order, gear clicks while the helm and planes wheels spin over (they turn to the order,
  not snap), heavy lever clunks, small dial clicks, a roar of air when the vents open and a hard
  hiss while blowing, a hydraulic whine as the periscope moves, a gurgling rush flooding a tube,
  a deep clang for doors and outer doors, a chain rattle for a reload, a diesel turning over and
  catching, pencil on the chart, footsteps that are very basic and subtle (a short,
  soft, muffled shuffle cut from recorded steps on carpet: no clank or plate ring, no low thud;
  Blaney found the first version sounded like knocking on his door and the second annoying and
  clanky; half as loud again now: your own barely there, a crewmate's just audible when close), a clang per ladder rung, a clink
  picking up or putting down a tool.
  **Shut doors keep the noise in** (Blaney): a sound from beyond a shut watertight door comes
  through dull (low-passed) and much quieter, quieter again for each more door; open doors and
  hatches let it straight through. Crew voices are not muffled.
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
- **Portholes:** round brass rims with eight bolts, in the wardroom (over the table and
  across from it) and either side of the mess table. Dark glass until you are close and
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
- **Crewmen** (Blaney, replacing lando's Sea of Thieves-style crew: "way too cartoony to the
  point where they are almost creepy, redesign them so everyone actually looks like sub
  sailors, make the models take less space"): normal proportions, slimmer (they take less
  room in the passageways too), a head of real size with small eyes, straight brows, a plain
  nose and a line of a mouth; no big forearms, glints or rosy cheeks. Still simple painted
  shapes. Pick build (average, wiry, stocky, broad), six skin tones, hair (cropped, crew cut,
  slicked back, side parting, wavy, short back and sides, curly; seven colours), face hair
  (clean-shaven, stubble, full beard, pencil moustache, sideburns, moustache, patrol beard),
  an extra (glasses, a cigarette long enough to see past a beard, with a filter end and a
  glowing tip, drooping from the corner of the mouth; scar, pipe, bandage), the rank hats (Dixie cup, watch cap,
  ball cap, officer's and skipper's caps, sized to the head) and a shirt colour, in
  "Your sailor..." on the main menu.
- **Enemy sub** (Blaney): a long dark cigar under the water with a conning tower, seen only through a
  porthole or camera if it comes close; never on a chart. Sonar hears "faint, steady screws —
  SUBMARINE" and roughly its depth; its torpedoes bring the alarm and "TORPEDO IN THE WATER". In the
  fight the chart shows only what we've seen: by eye (surfaced or scope up) the usual
  chart colours; by sonar (the patch under us, further with a ping) grey-blue dots on the chart and
  grey-blue relief on the table; the rest shaded paper and flat dark sand. Starts as a patrol on the
  menu, or "enemy sub" on the PA on any patrol, when the whole map comes back once she's gone.
- **Typhoon** (Blaney: exact layout, a whole crew of competent sailors; lando: the most realistic
  boat of the nuclear era): real full size, 175 m, so the walks are long and the sprint is faster.
  Five pressure hulls: two long main hulls side by side, a command hull above them, a torpedo hull
  forward and a steering hull aft, with two rows of ten pale grey-green missile tubes, numbered in red,
  either side of an aisle between the main hulls. Nineteen rooms, each signed over its doors in Russian
  with English under it. No exact plan is published, so the rooms within the hulls are our best fit.
  Reactor rooms have olive shielding with yellow ☢ signs either side of a narrow aisle. The long rooms
  have a lamp every 14 m or so. Short cross passages with watertight doors join the hulls. Sailors have Russian
  names and navy watch caps. "All hands" on the PA fills the boat: three men in each room you can see,
  stations manned, damage parties who walk through the doors and up the ladder, opening a shut door and
  shutting it behind them. Two notebooks on stands in the command bay: the first mate's list of
  everything wrong, and the skipper's of what's pressing, with "CHECK IN WITH THE FIRST MATE" when
  there's news. "Band play" sends forty hands to the rec room, eight on the instruments, playing The
  Foggy Dew or along with the record. Enemies are Cold War US ships and submarines. Music: a slow original
  men's choir over low strings and timpani (Blaney: the mood of The Hunt for Red October), the one
  soundtrack at sea, as loud as the menu music (at first it sat so far back he never heard it), silent while the band
  plays like all other music. **As real as we can get** (Blaney): where a Typhoon
  choice is between the game's usual look and the real boat, go with the real boat. Outside she is black
  rubber all over (her anechoic tiles): hull, fin and a deck a shade lighter, the missile hatches flush
  in two rows, no wood. **Inside, as in The Hunt for Red October** (Blaney): cold blue-grey steel
  (walls `#8E9BA6`, deckhead `#A9B3BB`, dark grey deck), cold blue-white lights, and the whole boat
  rigged for deep red while all hands are called. Walls packed with pipe runs (grey, blue, yellow,
  red), valves, gauges, Russian-stencilled junction boxes and cable looms. **Filled like a real
  boat in service** (Blaney: "the sub is empty", more pipes; modelled on *Dmitry Donskoy*, the last
  in service, retired 2023): a second bank of four pipes on each shoulder, a bundle along the
  deckhead clamped every 1.6 m, two bilge runs, wall gear every 0.6-0.9 m; grey equipment cabinets
  with screens and lamps down the centre passage; steam and coolant lines over the reactor shields
  with valves and gauges on their faces; steam pipes down into the turbines, a condenser under, gauge
  boards; each missile tube banded top and bottom with a red hatch wheel, a lamp box and a cable.
  Her real comforts in the gym, sauna and pool room: the pine sauna, a small tiled pool with blue
  water, a ladder and a life ring, weight benches and a rowing machine, a sun lamp, and an aviary of
  songbirds (КАНАРЕЙКИ) on the after bulkhead.
- **Typhoon command bay** (Blaney: a realistic layout, as in the film): the helmsman (starboard)
  and the planesman (port) sit side by side facing the bow, each at a black aircraft-style yoke on
  a blue-grey console with a green readout in Russian, under a bank of gauges. Planesman: hold W to
  push forward and go down, S to pull back and come up, Shift gently. Helmsman: A/D or the mouse
  turns the yoke for rudder, C centres, W/S the engine order lever by his right hand. Behind them a
  low round dais with a brass rail round the front and the scope, the attack scope beside it; the
  skipper's brown leather chair to port, sonar on the port wall, fire control to starboard.
  Bot crewmen sit in the chairs.
- **The skipper's hologram** (Blaney: a 3D view of the water from what the boat knows, everyone
  sees it; Typhoon only, blue glow): sit in the skipper's chair, H turns it on or off. It hangs in
  front of the chair from a projector in the deckhead: a ring for the sea's surface, the sea floor
  8 km round as glowing blue grid lines, our boat bright in the middle, bow ahead (heading-up),
  ships the boat hears or sees as small blocks with a thin line up from a sub's depth and a name and
  range, our torpedoes bright, theirs red. Past 8 km a contact sits on the rim on its bearing.
- **Crash surface** (Blaney: emergency breaching): an emergency blow from depth (X twice on the
  ballast, or "crash surface" on the PA) brings her up so fast her bow leaps out: up to 28° bow up
  and thrown 6 m out of the sea, slammed back down with a great splash, rocking to rest. Inside,
  everyone is shaken twice (the leap and the slam), the lights flicker, "CRASH SURFACE! Hold on!".
  A normal blow comes up gently.
- **All hands on deck** (Blaney, any boat; it only fills places, the lights and mood stay as they were): every post manned, three more men standing in each
  room, see-through so they never block the way (Blaney), damage parties on standby, and the crew
  work the patrol's objective by themselves until "stand down".
- **Packed walls on every WWII boat, the S-boat too** (Blaney: like the real one; then "overhaul
  the other sub types as well"): the Typhoon's density in WWII colours: four pipe runs (white,
  grey-green, red, blue) and a second bank of four (grey, brass, olive, white) on each shoulder, a
  deckhead bundle clamped every 1.6 m, two bilge runs, wall gear every 0.6-0.9 m: valves, gauges,
  stencilled boxes (FRESH WATER, HP AIR, HYDRAULIC, FIRE MAIN), pipe drops, cable looms. In the
  control room the real boat's "Christmas tree" (HULL OPENINGS: rows of lamps on the forward
  bulkhead, starboard of the door, two red while the diesels breathe on the surface, a straight
  green board dived), the HP air manifold's six wheels on the after bulkhead and phone handsets.
- **Bot crewmen stand naturally** (Blaney: natural positions at every station): feet on the deck
  at a spot each station gives, held the way the job asks: hands on the wheel or yoke, both up on
  the periscope handles, leaning over the chart, one hand on the sonar wheel,
  watching the camera screens hands down, a dart up by his ear, a round held up at the scuttle,
  sitting on the arm rests in the skipper's chair. Torpedomen stand one behind another down their
  tubes' side of the room. Name tags half the size they were.
- **Handing over** (Blaney): J at any station: a bot takes it over and you walk off.
- **Bot crewmen:** look like any crewman (random build, face and shirt, a navy watch cap),
  standing their station with hands on the gear and a name tag with their job ("Sparks
  (planesman)", "— on orders" when following yours). They speak through the same announcements
  as everything else: "Stubby (sonar): contact bearing 270, warship, turns for 20 knots."
- **Volume** (Blaney): quieter out of the box: master 40%, effects 70%, music 50%, voices 100%.
- **Out any time, god mode** (Blaney): for now the hatch opens at any depth; dived, you climb out
  into the sea in the dive suit. "God mode" on the PA is for the one who says it: super speed on
  foot and in the sea (faster than any boat), and nothing knocks you out.
- **The crew through the cave** (Blaney): "take us through the cave" on the PA, or "all hands" on a
  cave patrol, and the bots take her through slow and in the middle while you ride along. The PA
  panel shows every order it knows, by kind; `docs/pa_commands.md` is the long list.
- **PA system** (Blaney): a grey 1MC speaker box with a hanging microphone on the control room's
  after bulkhead, to port of the door. E opens a typing box; Enter sends. The skipper's words show
  big for everyone with the bell, the crew's answer on the message line, and the order stays top
  right under SKIPPER'S ORDERS until it is done. Plain English, and the crew work it out; if they
  can't: "Say again, Skipper? We didn't follow that one." Anything they do goes through the same
  stations: bots take up any empty post they need, and a player at that post is told it's theirs.
- **Bilge pump:** a grey-green panel low on the control room's forward bulkhead with a blue
  ribbed motor, a suction pipe into the bilge, a red switch and a green lamp; it shakes and
  whirrs while it pumps.
- **Crouch:** hold Ctrl: your eye drops to 1.05 m, you move at half speed and your boots are
  near silent; crewmates see you squat down.
- **Emotes:** 1 wave, 2 salute, 3 jig, 4 point, 5 cheer. The camera swings out in front, a
  little to one side wherever the hull has room, so you see yourself; moving ends it.
- **Rec room** (games picked by Claude while lando was away; add more): between the crew's
  quarters and the engine room on the Gato and Narwhal. A dartboard on the starboard wall (real rings and
  scoring, a swaying aim, three darts a turn, best turns chalked up and called out to the
  crew), a jukebox with an amber glow that the room hears (Blaney: both our own songs and crackly old
  records: the shanty, the slow watch, The Foggy Dew by the whole band; Anchors Aweigh by the
  Naval Academy Band in 1920 and the Navy Band in 1929, Over There by Billy Murray in 1917), a
  green-baize card table, a porthole.
- **Music** (`tools/make_music.py`, played on real recorded instruments in stereo, Blaney; style
  picked by Claude while lando was away, to match the Sea of Thieves direction; change it
  freely): the menu is an original D-minor sea shanty on accordion with oom-pah tuba and
  stomp-clap, and the debrief goes back to it. At sea there is no background music (Blaney): the
  music aboard comes from the band's instruments and the jukebox, which has the calm "Slow watch"
  (a sparse pad and a lonely flute). While anyone aboard plays an instrument, the jukebox and any
  other music fall silent within a second, and come back when they stop.
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
- **Pastimes (Blaney):** arm wrestling across the mess table (tap Space, the locked fists swing
  toward the loser), blackjack against the house at the card table (cards face up on the baize),
  the cook's special at the galley range (a swinging heat needle, flip in the green, three flips
  make a meal called out to the boat), fishing off the stern rail (strike, then reel keeping the
  line's tension in the green). A bot takes on all comers at any empty seat. Each fun spot glows
  warm with its name in cream caps when you walk within a few metres. **T** opens the "things to
  do aboard" card: every pastime on this boat, its room, its keys, what needs her surfaced, and
  the crew's records; "[T] things to do" sits small in brass in the bottom-left corner.
- **Training crew calls (Blaney):** in the short per-job courses, the crewmates you would
  hear are played for you: a big line near the top, the speaker in brass caps and the words
  in cream quotes ("CAPTAIN: "Come to course zero-niner-zero.""), with a short bell like an
  order over the boat's speakers. Training opens on a list of jobs to pick from; the long
  whole-boat course stays at the bottom.
- **Crew training together (Blaney):** Training's menu has two columns, ON YOUR OWN and WITH
  FRIENDS (Attack team, Control room, Damage party). You take a job by manning its station. The
  panel top right ends with who has what ("Periscope: Lando · Torpedoes: open"); when the step is
  someone else's it says "Waiting on Lando (periscope)." and shows their orders. A crewmate's
  call shows with their name and job in place of the scripted voice.
- **UI:** typewriter / stencil feel, cream on dark panels, minimal HUD (crosshair, carried
  tool, interaction prompt).

- **Our boat from outside** (Blaney: real details, smoother hull, weathered paint, every boat
  as far as real life has them, the Typhoon most; `world/own_boat.gd`): a round lofted hull cut
  flat by the casing, a streamlined fin with a rounded top edge. WWII boats: dark grey streaked
  with rust down from the casing and fin, salt at the waterline, black below; teak deck,
  limber holes, stanchions and lifelines, bow and stern planes, rudder and twin bronze screws,
  anchor, bridge with windscreen, periscope shears, SJ radar and SD mast, a 20 mm on the
  cigarette deck (not the S-boat), the hull number in white on the fin (S-44, SS-212, SS-167),
  torpedo loading hatches; the Narwhal's second 6-inch gun aft. Typhoon: matte black rubber
  tiles with some torn off, a wide flat deck, twenty missile hatches forward of the sail,
  bridge windows, masts drawn down, white rescue-buoy frames, white draught marks, bow planes
  folded low, stern planes with end plates, the tall upper rudder and two shrouded screws.
  The deck hatch sits clear forward of the fin on every boat; what you walk and swim against
  is the same shape as what you see.
- **Deep down** (Blaney: scary deep; Typhoon very deep, WWII boats realistic): orders go all the
  way to crush depth (Gato 150 m, Typhoon 500 m). The hull creaks more and louder the deeper she
  goes; near test depth frames bang, the boat jolts and water weeps from the seams; past it the
  lights waver. Outside the water is dim by 100 m and close to black by 300 m.
- **The sea** (Blaney: a larger area): islands, seamounts and shelves spread over some 30 km
  each way, with deep trenches far below any keel; the chart table zooms out to 80 km across;
  swimmers have 40 m of sea round the boat.

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
| 2026-10-30 | lando | Work on the deck gun and weather (weather: rain and squalls that roll across the patrol, cutting how far lookouts and the periscope see, cover to close in on a convoy, rougher seas and darker skies with them). |
| 2026-10-31 | Blaney | Bot crewmates' arms stick out behind them and not toward the station they're at: hands go forward onto the gear. |
| 2026-10-31 | Blaney | Dart board: no line on the ground that blocks you from moving; you just walk up to the board to play darts. |
| 2026-10-31 | Blaney | Fix the footsteps, they're very annoying and clanky; they should just be very basic and subtle footsteps. |
| 2026-10-31 | Blaney | When the sub is high enough above water, make it possible to get out and walk on top of it. The boat can't dive with crew out; fall in and you swim back and climb a ladder. |
| 2026-10-31 | Blaney | Add a top-of-the-sub wrestling game where you try to wrestle the other person into the water, like a simplified Your Only Move Is HUSTLE with only Greco-Roman moves; pick moves then they play out; start it by stepping into a ring marked on deck. |
| 2026-10-31 | Blaney | The character models are way too cartoony, to the point where they are almost creepy: redesign them so everyone actually looks like sub sailors, and make the models take less space. (Style conflict with lando's 2026-10-30 Sea of Thieves-style crew.) |
| 2026-10-31 | Blaney | Add cameras around the outside of the sub, with a viewing centre: a wall of small screens of every camera, plus pick one to show big. |
| 2026-10-31 | Blaney | Make a navigation room that shows the whole terrain of the region we're exploring as a topographical map: a raised 3D model on a table (sand table) with our boat as a marker moving on it. |
| 2026-10-31 | Blaney | Add instruments of all types that all play parts of a sea shanty like Sea of Thieves, so when all the instruments are in it is a complete song; first "The Foggy Dew" (Chieftains, classic Irish melody). A mix of modern and traditional instruments; take one and play it anywhere. |
| 2026-11-03 | Blaney | The cigarette didn't appear in my mouth: make it clearly visible. |
| 2026-11-03 | Blaney | Arcade torpedoes twice as fast (about 40 s to a ship 2 km off). |
| 2026-11-03 | Blaney | Arcade: no TDC or gyros, just point the bow and fire, with a lead marker on the periscope showing where to point. TDC and gyros saved for realistic. (Kept in Standard too, since lando wants existing mechanics kept until tried.) |
| 2026-11-03 | Blaney | There should be a multi-crew tutorial for each section: each job's course taken by two or more players together, real crewmates giving the calls instead of the scripted ones. |
| 2026-11-03 | Blaney | All the sleeping quarters should not be near the weapons or operation areas. |
| 2026-11-03 | Blaney | The sound quality needs massive improvement: use real recorded samples from free-to-use libraries, starting with the band instruments, sound effects and the jukebox. Footsteps even quieter. |
| 2026-11-03 | Blaney | Footsteps half as loud: your own barely there, a crewmate's just audible when close. |
| 2026-11-03 | Blaney | The jukebox plays both our own songs on real recorded instruments and a few crackly old records, free ones only. |
| 2026-11-04 | Blaney | There should not be background music in the game; the only music should be from the instruments. "I like the menu music, and I like the instruments, can we make it so that the other music stops when we play instruments?" (Style conflict with lando's 2026-10-30 "Add music": the menu stays, the patrol and hunted tracks and the debrief stings go.) |
| 2026-11-04 | Blaney | Make sprinting a bit faster (for the full-size Typhoon). |
| 2026-11-04 | Blaney | A way to spawn bots to take over your role if you are occupying a position. A PA microphone you can type into that tells the crew the current objective: a general crew instruction system, automatic once a command is done, that says so if the crew are confused and is relatively intuitive ("go sink the ship to the east", "dive to the bottom of the ocean"); it learns more as more is built. |
| 2026-11-04 | Blaney | An option to start a battle with another enemy sub near you. Your map cannot show the sub, only the map around your sub given the equipment you have: with only sonar the map looks different than relying on eyesight above water. It starts from the menu or on the PA with the keyword "enemy sub"; the limited map is only for these fights. |
| 2026-11-04 | Blaney | Build a Typhoon-class sub with exact layout details and a whole crew of competent sailors you can spawn in. The PA in the command bay commands them. A first mate's list shows everything wrong with the sub, and sailors can fix any issue given time; a bot or a player can possess the notebook. The skipper's notebook says what's pressing, with a note to check in with the first mate when there's news. "Make sure this sub change doesn't lag anything out." |
| 2026-11-04 | Blaney | The Typhoon is real full size (175 m) with a faster sprint, fights Cold War enemies, and has music and sounds in the mood of The Hunt for Red October. (An original piece: the film's theme is copyrighted. Style conflict with his own "no background music at sea": the Typhoon alone has a soundtrack, at his choice.) |
| 2026-11-04 | Blaney | The Typhoon can make a decent portion of the crew play whatever song is being played, at the skipper's command. |
| 2026-11-04 | Blaney | Typhoon damage parties shouldn't walk through walls: send them through the doors. |
| 2026-11-04 | Blaney | (On the Typhoon's deck: tan wood or black rubber like the real boat?) "Definitely as real as we can get for the typhoon." |
| 2026-11-04 | Blaney | "I dont know how to make the choir happen, no music like that that i hear." (It played, too quietly, and stops while the band plays: now as loud as the menu music.) |
| 2026-11-04 | Blaney | Add more detail to the Typhoon and Gato. For the Typhoon look at scenes from The Hunt for Red October. (Then: Typhoon lit like the film, cold blue-white and red at battle stations; Gato packed like the real one.) |
| 2026-11-04 | Blaney | A realistic control scheme and positions for the Typhoon bridge. (Then: two seats side by side at aircraft yokes, helmsman and planesman, the skipper behind at the periscope.) |
| 2026-11-04 | Blaney | A command "all hands on deck" that completely fills the sub with people controlling everything needed for the current objective. (Then: the crowd see-through, never blocking.) |
| 2026-11-05 | Blaney | Add emergency breaching. (Then: a crash surface, the bow leaping out and slamming down.) |
| 2026-11-05 | Blaney | A control panel where the skipper sees a 3D view of what is happening in the water from all the information the sub has, in front of him when he takes a position on the bridge; everyone sees the hologram when he toggles it on. (Then: Typhoon only, blue glow.) |
| 2026-11-05 | Blaney | (After playing the bay, hologram, all hands and crash surface: "very good".) The Typhoon is empty: fill it up, more pipes, and make it accurate to a real Typhoon that's in service. |
| 2026-11-05 | Blaney | Overhaul the other sub types as well; in all the sub types the characters should be in natural positions at their stations; all hands on deck mustn't change the vibe to stressful, it's only to fill places. (Undoes his own red light at all hands.) |
| 2026-11-05 | Blaney | Even more filled up: the control room easy to move around, but more pipes and stuff so the subs feel full and working underway; accurate kitchen and living areas; the sub should look lived in. (Asked: lived in but tidy, not cluttered; both family photos and 1940s pin-ups; a busy galley with steam, a sizzling pan and a cook; all four boats, the Typhoon too.) |
| 2026-11-05 | Blaney | (After playing the lived-in Gato: "the gato feels good".) Doors should insulate noise, like the engine. |
| 2026-11-05 | Blaney | More fun things to do in the game, clearer ways to access them, and a list of the things we can do. (Asked: all four of cards in the mess, fishing off the deck, cooking in the galley and arm wrestling; the list on a key easier for a casual player to hit than F1; each fun spot glows softly with its name when you're close.) |
| 2026-11-06 | Blaney | We need this sub to get scary deep: the Typhoon class should be able to get very deep, the WWII ones realistic. A better outside of the sub: real details, smoother hull shape, weathered paint; good, working outsides of all the subs as far as they exist in real life, the Typhoon most (he tests on it a lot). |
| 2026-11-06 | Blaney | A larger area that the sub can go (he hadn't checked how far it went: "that takes a while"). |
| 2026-11-06 | Blaney | (After playing the new outsides, hatch, deep dive and the T list on the Typhoon: "great, thanks".) |
| 2026-11-06 | Blaney | An underwater navigation challenge: a short cave to go through and out the other end; every boat can do it, but an inexperienced crew needs coordination. (Asked: both its own timed challenge on the menu and caves hidden in the open sea.) |
| 2026-11-06 | Blaney | Dive suits and spots to hold on to, so the boat can dive with someone outside as a lookout telling us where we're going; he can't get back in until she surfaces. (Asked: the suit depends on the boat's era: "the game should no longer be only a WWII sub game, the time period will change with the type of sub you board". Letting go or going deep: "there will be ocean floor exploration later so dont have it be instant death but make there be a button to return to the sub if the sub gets too far away".) |
| 2026-11-06 | Blaney | Terrifying sea creatures that live in the depths, that can be hunted or hunt us, and a PA command to spawn one. (Asked: giant squid, giant anglerfish, sea serpent and megalodon, all four; creepy dread: strange sounds, shapes in the dark, the hull groaning when one grabs you, no gore.) |
| 2026-11-06 | Blaney | Add the OceanGate Titan, controlled with a game controller like the real one. (Asked: for deep exploring, no weapons, up to 5 crew; too deep she cracks and warns first, then implodes once she can't take any more.) |
| 2026-11-06 | Blaney | Getting around with a full crew should be doable, and in arcade the boat should move faster: "I don't want the game to be a waiting simulator". (Asked: about twice as fast, speed, turning and diving; crewmates walk through each other.) |
| 2026-11-06 | Blaney | The crew's hats go through their heads. |
| 2026-11-06 | Blaney | "I do want to be on board when the crew does it": a PA order for the crew to take her through the cave on their own, and a long list of all the PA commands. |
| 2026-11-06 | Blaney | Swimming to the sea floor, out of the sub while dived, and in flooded rooms. The sand table goes: the navigation room is mostly a giant hologram showing everything for testing (even what the boat hasn't found). A captain's chair in every boat, with the keys on its card (W/S speed, A/D turn, R/F depth, 1-4 presets, C crash dive, X emergency surface, Tab target, Space fire, P scope, N/M waypoints, H hologram, Q leave): bots carry out each order unless a player is on that station, so there is no interference. Waypoints the boat steers to itself, set on the chart, from a list of places or on the PA. Sea-floor places: shipwrecks, ruins, glowing vents and gardens, alien civilizations. |
| 2026-11-06 | Blaney | "Make it so i can also exit the boat at any time for now", and "god mode" on the PA: "superspeed and invincibility and super swim speed so i can catch up to subs and watch them from the outside". |
| 2026-11-06 | Blaney | "Lets get rid of the sand table." |
| 2026-11-06 | Blaney | "Lets also just turn the volume down, i think it is by default too loud." (Defaults now master 40%, effects 70%, music 50%; saved settings keep their own.) |
| 2026-11-06 | Blaney | "The captains chair should have a PA button so that you can type from there." (Enter, from the chair; every captain's chair to come has it too.) |
| 2026-11-06 | Blaney | "There are pipes in the way of the tv screen as well." (The outside cameras' console now stands out from the wall, its screens in front of the pipe runs.) |
