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

*Ticked here = Blaney has checked it and it waits on lando: as of 2026-11-04 everything ticked below is in PRs #28-#35, ready for lando to merge. VibeNote shows an item done only once every branch on GitHub has it ticked, so these turn done there when lando merges and the old branches are deleted.*
- [x] **Pause menu**: Esc brings up a menu (resume, settings, leave to main menu). The boat
      keeps going while it is open when others are aboard; it only truly pauses in single player.
- [x] **Fix the helm wheel**: it turns on the wrong axis. It should spin around its own
      axle, like a car's steering wheel, when the rudder moves.
- [x] **Tutorial: tell you to leave a station**: when the next step is somewhere else,
      prompt "press Q to leave the station" before sending you on.
- [x] **A more nimble boat**: "more nimble than physically possible to a slight extent so
      that people don't get bored, but not so that we're in a rocket ship". Faster turns, dives
      and speed changes than the real thing, still heavy and submarine-like.
- [x] **Portholes**: some windows to look out of from inside the boat.
- [x] **Frutiger Aero coral reef**: shallow, bright, clear water with coral, fish and sea
      floor terrain to look at through the portholes and periscope, "almost like you'd see
      on a nostalgic soap pump bottle at school".
- [x] **Tutorials per crew position**: the one 29-step training patrol is too long. Split it
      so you pick the position you want to play (helm, dive, periscope/TDC, sonar, torpedoes,
      engine/air, damage control...) and do a short tutorial just for that. Each one includes
      the information you would normally hear from the other players aboard (e.g. "Captain:
      come to 090", "Sonar: contact bearing 270") so it works alone.
      *(Training patrol on the menu opens a list: Helm & dive, Periscope & TDC, Torpedoes,
      Sonar, Damage control, Engine & air, and the whole boat (long). Crew calls pop up big
      with the speaker's name and a bell.)*
- [x] **Footsteps that don't sound like knocking**: "the footsteps make it sound like someone
      is knocking on my door which is not optimal". They should read as boots on a steel deck,
      not a knock on wood (ask Blaney what he wants instead when this is picked up).
      *(Redone: a soft heel and gritty scuff with a faint ring, no low thud, and your own steps
      quieter. Left open until Blaney says whether it works.)*
- [x] when the sub is high enough above water make it possible to get out and walk on the top of it
      *(Surfaced, E at the bridge hatch over the gun's ladder climbs out on deck; off the side you swim and climb back up a side ladder; no diving while anyone is out.)*
- [x] add cameras around the outside of the sub, there should be a viewing center
      *(In the new navigation room: six outside cameras (bow, stern, port, starboard, bridge, keel) on a wall of small screens, and a big screen; man the console and 1-6 picks it.)*
- [x] fix the footsteps, theyre very annoying and clanky, they should just be very basic and subtle footsteps
      *(Redone again: a short soft muffled shuffle, no clank, ring or thud, and quieter all round. Covers the knocking item above too.)*
- [x] add a top of the sub wrestling game where you are trying to wrestle the other person into the water, it should work like a simplified version of your only move is hustle where only greco roman wrestling moves are allowed
      *(A ring painted across the aft casing: two step in, each turn both pick a Greco-Roman move in secret (push, arm drag, body lock, suplex, brace) and they play out together; driven off your edge, you go in the sea.)*
- [x] make a navigation room that shows the whole terrain of the region that we are exploring in a topographical map on a wall or a table
      *(A navigation room aft of the control room in every boat, with a raised sand-table model of the whole patrol area and a brass boat marker that moves with us.)*
- [x] add instruments of all types that all play parts of a sea shanty like sea of theives, so when all the instruments are in then it is a complete song, first add the song "in the foggy dew" by the chieftains (classic irish melody)
      *(A ship's band rack (rec room; the S-boat's in the navigation room): tin whistle, fiddle, concertina, bodhrán, electric guitar, bass, snare, keytar synth. Take one, hold LMB to play; every part runs on one clock so they join in time, all eight make the whole of The Foggy Dew.)*
- [x] i cannot get into the vpn game with lando, my screen is just grey
      *(Cause: the installed Sub of Seas is the release pin (3a43195), from before the ZSTD
      change, and can't finish connecting to a host on newer code, so it sat on the grey
      screen forever. Now a joiner that hasn't got the boat after 20 s goes back to the menu
      and says why. To play together, both run the same version: the pin needs bumping, or
      Blaney joins from his clone with `./play join`.)*
- [x] dart board should not have a line on the ground that blocks you from moving, you should just walk up to the dart board to play darts
      *(No line and nothing invisible on the floor any more: walk up to the board and press E at it.)*
- [x] bot crew mate arms at sticking out behind them and not toward the station theyre at
      *(Fixed: arms at a station swung backwards; they now reach forward onto the gear, for bots and players alike. The point and salute emotes had the same backwards arm and are fixed too.)*
- [x] the character models are way too cartoony to the point where they are almost creepy, redesign them so everyone actually looks like sub sailors, make the models take less space
      *(Redesigned as WWII US submariners in ordinary proportions: slimmer, a real-size head with plain features, chambray shirt, dungarees, boots; period hair and face-hair options; smaller collision so they take less room.)*
- [x] clean up the game files, do a quick check for bugs, make sure lando can see all the changes
      *(Every training course, all six patrols on all three boats with bots, and a two-player session run with no script errors; old merged branches removed; leftover debug code checked for; every change is on GitHub in PRs #16 and #18-#26, merged in that order.)*
- [x] the footsteps should still be even quieter
      *(Done: half as loud as before, and cut from recorded steps on carpet with no low thud. Your own barely there, a crewmate's just audible when close and gone a few metres off.)*
      *(PRs #27, #28 (arcade aim), #29 (crew training), #30 (crew's quarters) and the sound pass stack in that order. #28-#30 are drafts until Blaney has played them; the sound pass (#31) is ready.)*
- [x] the cigarette didnt appear in my mouth, i dont think all my character options saved
      *(The options did save; the cigarette was a tiny dot lost in a beard. Now longer, with a filter end and a glowing tip, sticking out of the corner of the mouth past any beard.)*
- [x] the pipe in my mouth and the cigarette dont appear when i join into lando's server
      *(The host threw away everything in a joining crewman's look but hat, shirt and rank, so face, hair, beard and extras never reached anyone, him included. It now keeps them all.)*
- [x] torpedos take way too long to travel, they should be faster in arcade mode
      *(Twice as fast in Arcade (92 kn), about 40 s to a ship 2 km off. Standard and Realistic keep the Mk 14's 46 kn.)*
- [x] there should be a multi-crew tutorial for each section
      *(Done: Training's WITH FRIENDS column: Attack team (periscope + torpedoes), Control room (helm + planes + sonar), Damage party (damage control + engine & air). Man a station to take its job; the panel shows who has what and "Waiting on Lando (periscope)" when it isn't your step; calls come from the crewmate holding the job ("LANDO (PERISCOPE): Flood tube one"). A job nobody has can be done by anyone, so it also works alone.)*
      *(Blaney chose: each job's course can be taken by two or more players together, e.g. torpedoes: one on the periscope, one on the tubes; real crewmates give the calls instead of the scripted ones.. Not started.)*
      *(Plan from 2026-11-03: the tutorial is one shared step list (`crew.tutorial.step`) that any player can work, so the missing part is the hand-off. Add crew courses that pair jobs that talk to each other (attack team: periscope + torpedoes; control room: helm + dive + sonar; damage party: damage control + engine & air). Each job is held by the player who mans its first station; the HUD tells only that player to act and shows others "waiting on <name> (periscope)". When the caller's job is held by a real player, his own finished step is the call, shown as "<name> (periscope): Fire one!" instead of the scripted voice. Training menu: a "with friends" section. The arcade aim step (`aim`) already exists.)*
- [x] the bedroom should not be next to the torpedo room, you shouldnt have to sprint across the sub to get to a place you will often go to
      *(Done: the only bunks are now in a new crew's quarters amidships, between the mess and the rec room (S-boat: aft of the navigation room), three tiers either side of an aisle. None in the torpedo rooms, the mess, or officers' country, which is now the wardroom with lockers.)*
      *(Blaney: "all the sleeping quarters should not be near the weapons or operation areas". Plan: no bunks in the torpedo rooms or next to the control room; one berthing compartment between the crew's mess and the rec room (S-boat: aft of the navigation room). Check portholes, `--spawn` examples, the tutorial's spots and the tests when moving rooms. Not started.)*
- [x] one instruments need improvement, the music quality needs massive improvement, the sound quality in this game in general does too
      *(Done, and Blaney has listened: "sounds good". The band and soundtrack play real recorded instruments, the soundtrack in stereo; 38 sound effects are real recordings, including a WWII Navy dive klaxon; the jukebox has The Foggy Dew and three old records; looping sounds now play right through, before this they only repeated their first fifth. Sources and licences in `docs/credits.md`.)*
      *(Blaney chose: use real recorded samples from free-to-use libraries (CC0 or similar, every one listed in `docs/credits.md`). Start with the band instruments, the sound effects and the jukebox. Do the even-quieter footsteps in the same pass. Not started.)*
      *(Blaney chose for the jukebox: both our own songs on real instruments and a few crackly old free records.)*
      *(Sources checked 2026-11-03, nothing downloaded for the game yet. Instruments: VCSL, CC0 (github.com/sgossner/VCSL, branch `master`), and FluidR3_GM rendered per note (github.com/gleitz/midi-js-soundfonts, `FluidR3_GM/<instrument>-mp3/<note>.mp3`, the repo says CC BY 3.0, so credit it). Records, public domain on Wikimedia Commons: "Anchors Aweigh, 1929 recording", "Anchors Aweigh played by the USNA Band in 1920". Klaxon, public domain on Commons: "WWII submarine dive klaxon". Effects: Freesound search filtered to `license:"Creative Commons 0"` gives preview mp3s (`data-mp3` in the page); kenney.nl refuses scripts. Plan: swap the voices in `tools/make_shanty.py` and `tools/make_music.py` for samples, keeping the arrangements; replace effects where a good recording exists, keeping a synth one otherwise; re-check every licence and list it in `docs/credits.md`. Claude can't hear, so Blaney judges each result by ear.)*
- [x] arcade mode should not use the TDC or gyros, we will save that for realistic, and in arcade it should just be: angle the bow of the target toward the ship and fire
      *(Blaney chose: a lead marker on the periscope, a small mark ahead of the ship: point the bow there and fire; torpedoes run straight out of the bow, gyro 0. Plan: TDC and gyros stay in Standard and Realistic (lando wants existing mechanics kept until tried, so they are kept, just not in Arcade); the Periscope & TDC and torpedo training courses need an arcade version. Do it with the faster torpedoes.)*
      *(Done: red AIM marks on the periscope lead each ship, a brass BOW tick shows where she points, green FIRE! when lined up; torpedoes straight out of the tube. The TDC cabinet says how to aim in Arcade. Training plays at the host's level, and Arcade's periscope course aims instead of marking.)*
- [x] we are having an issue with not being synced up on what changes have been done and what are on the list wrong so really check before changing anything to see if there is a conflict or something that would make it strange to have both things in the game at the same time - consider this task as the first one in this group
      *(Checked 2026-11-03 against main after PRs #16-#26: ten items on Blaney's notes were already in the game and ticked; only the ones here were open. Clashes to watch: Arcade without the TDC vs lando's "keep all existing mechanics until tried with others" (kept for Standard/Realistic, flag as a style conflict in that PR); the training courses assume the TDC; faster torpedoes shorten how long escorts get to spot a track; moving the bunks touches the portholes and the style guide's compartment descriptions.)*
- [x] lando says to commit and push sub of seas to a branch as wip so his claude can see what's being done. make sure to do that for both of us in the claude.md
      *(CLAUDE.md "Push work in progress as you go": both of us commit part-done work as `wip(...)` on our branch, push it with a draft PR, and every session starts by looking at the other's unmerged branches.)*
- [x] the typhoon class sub should be able to make a decent portion of the crew play whater song is being played at command of the skipper
      *("Band play" on the PA: forty hands to the rec room, eight on the instruments, playing The Foggy Dew or along with the record; "stop the music" sends them back.)*
- [x] there should be a way to spawn bots to take over your role if you are currently occupying a position, there should be PA system microphone that you can type into that tells the crew the current objective, it will learn more things you can the crew to do as more things are built into the game, but this is a general crew instruction system that should be automatic once a command is done, if the crew is completely confused then it will say so but it should be a relatively intuitive system. things like "go sink the ship to the east" or "dive to the bottom of the ocean" it will know what you mean and have the crew do what you need
      *(Done: J at any station hands it to a bot. A PA microphone in the control room: E, type, Enter. It understands depths, courses, speeds, attacks ("sink the ship to the east"), escaping, battle stations, standing down, fixing damage, reports, sonar, objectives; bots man whatever the order needs, a real player at a post is told it's theirs; confused, the crew say so. New orders: `game/crew_command.gd` + `BotCrew._carry_out`.)*
- [x] build a typhoon class sub with exact layout details and the ability to spawn in a whole crew of competent sailors. the PA system in the command bay should be able to command the crew effectively. there will be a first mate list that shows everything wrong with the sub at the moment, the sailors should be able to fix any issue given a period of time. a bot can posess this notebook or a player can posess it, the skipper will have a different notebook and it will say other things that are pressing in terms of commands, maybe also a note to check in with the first mate when he has new news. make sure this sub change doesnt lag anything out
      *(Done, PR #35: five hulls, 19 rooms, all hands on the PA, first mate's and skipper's notebooks, damage parties through the doors, the band, Cold War patrols, a choir. Blaney played it: "wow this is great".)*
- [x] Typhoon: screenshot every room and look at them (doors, cross passages, Russian signs, notebooks, her outside)
      *(Done: `tools/room_tour.gd`, `tools/typhoon_looks.gd`. Found and fixed a dartboard, bunks and a turbine in front of doors and a flickering floor.)*
- [x] Typhoon: compare the frame rate with a Gato, with all hands aboard (Blaney: must not lag)
      *(Both 60 fps in every room on Blaney's RTX 3060 at 1280x720. Worst room to draw: Typhoon 3.9 ms CPU / 3.6 ms GPU, Gato 1.6 / 2.6, out of 16.7 ms a frame. Script time per frame the same on both (16-19 ms as Godot reports it). `tools/room_tour.gd`.)*
- [x] Typhoon: Blaney plays it, and judges the choir music and sounds by ear (Blaney: Hunt for Red October mood; the film's theme is copyrighted, so it's an original piece)
      *(Played 2026-11-04: "wow this is great". He couldn't hear the choir; made louder, and he signed it off.)*
- [x] Typhoon: the choir can't be heard: find out why and make it audible (Blaney: "i dont know how to make the choir happen, no music like that that i hear")
      *(It played, at -13 dB, lost under the boat, and stops while the band plays. Now as loud as the menu music. Blaney still to judge it by ear.)*
- [x] Typhoon: as real as we can get (Blaney). First her outside: black rubber hull, not the WWII boats' tan wood deck
      *(Done: hull, fin and deck in black rubber.)*
- [x] Typhoon: damage parties walk through walls; send them through the doors
      *(Done on every boat: along the rooms, through doors and up the ladder; they open a shut door and shut it behind them.)*
- [x] Run the whole of `make test` on `blaney/typhoon` (every training course, after the interior rework; results in `docs/notes.md`)
      *(Clean, 2026-11-04: 563 unit tests, every training course, the enemy sub, the Typhoon, damage parties on all four boats, every door.)*
- [x] Typhoon: bring `docs/style.md`, `docs/credits.md`, `CLAUDE.md` and the `Makefile` up to date, then mark PR #35 ready
      *(Done; PR #35 marked ready 2026-11-04.)*
- [x] Blaney plays the music change (#32), the PA and bots (#33) and the enemy sub (#34), so Lando can take them out of draft
      *(Played 2026-11-04 with #28 and #30: "the game works". #28-#35 all marked ready; #29 not yet tried by two players together.)*
- [x] generate an option to start a battle with another enemy sub somewhere near you, your topographical map cannot show the sub, only the map around your sub given the equipment you have, so if sonar is the only way you can see then the map would look different than being to rely on eyesight above water
      *(Done: "Enemy Sub" on the patrol menu, or say "enemy sub" on the PA on any patrol. She hunts by ear and fires pairs of torpedoes; sonar is how you find her, and a torpedo has to run near her depth. In the fight the chart and sand table only show what the boat has seen: clear by eye, dotted grey-blue by sonar, the rest unknown.)*
- [x] there should not be background music in the game, the only music should be from the instruments
      *(Done: nothing plays at sea but the band and the jukebox; the menu keeps its shanty (Blaney likes it), and the jukebox goes quiet while anyone plays an instrument. Sprint is a bit faster too: 2.1× walking.)*
- [x] disregard anything from this list already sent off to landon
      *(Checked 2026-11-04: everything else on the list was already ticked and on GitHub, so only the Typhoon, the PA and bots, the enemy sub and the music were done.)*
- [x] lets add more detail to the typhoon and gato class subs. for the typhoon i want you to look at screenshots from scenes in Hunt For The Red October which is a submarine movie
      *(Done: walls packed with coloured pipe runs, valves, gauges, stencilled boxes and cable looms on the Gato, Narwhal and Typhoon; the Typhoon in the film's blue-grey steel, blue-white lights, red at all hands.)*
- [x] add a realistic control scheme and positionings for the typhoon bridge
      *(Done: helmsman and planesman side by side at yokes facing the bow, the periscope dais and the skipper's chair behind.)*
- [x] add a command "all hands on deck" that completely fills the sub with people controlling everything that needs to be done for the current objective
      *(Done: any boat; every post manned, three more men in each room, see-through, and the crew work the objective until "stand down".)*
- [x] add emergency breaching
      *(Done: a crash surface. An emergency blow from depth, or "crash surface" on the PA, and her bow leaps out and slams down.)*
- [x] add a more in depth control panel so the skipper can have a 3D view of what is happening in the water based on all the information the sub is providing him, when he takes a certain position in the bridge then he is able to see in front of him (along with other connected players in the lobby, everyone should see this hologram if the skipper toggles it on)
      *(Done: the Typhoon's skipper's chair, H: a blue hologram of the sea floor, contacts and torpedoes for everyone.)*
- [x] fill up the typhoon, it's empty: more pipes, and make it accurate to a real typhoon that's in service
      *(Done, PR #37: pipe banks, cabinets, reactor and turbine pipework, missile tube fittings, the real boat's sauna, pool, gym and aviary.)*
- [x] lets overhault the other sub types now as well, make sure that in all the sub types the characters are in natural positions when they go to their stations, dont make all hands on deck change the vibe to stressful (its only to full places)
      *(Done, PR #38: every WWII boat packed like the Typhoon, the Christmas tree board and HP air manifold; bots stand naturally at every station; all hands keeps the lights as they were.)*
- [x] i want the subs even more filled up, the control room should be easy to move around but i want more pipes and stuff to make the subs feel full and funtional as they are underway. accurate kitchen quarters and living areas as well. the sub should look lived in
      *(Done, PR #39: a galley with its cook, laid tables, lived-in bunks, photos and pin-ups, more pipes, on all four boats; shut doors now muffle the engines and every other sound.)*
- [ ] youve done a good job on the feeling of movement in the game but we need more of it, every axis of movement should be felt and the sub should be realistically stable when still (it would still have some roll and pitch)
- [ ] lets add more fun things to do in the game and clearer ways to access them and see a list the things we can do

## M9 — Lando's list (2026-10-30)
Added by lando. Direction: **more arcadey, not strict realism**. Every existing mechanic
stays for now, until they have been tried with others.
- [x] **Settings menu**: audio (master / music / effects / voice volumes), graphics
      (resolution, window mode, quality, field of view), controls (mouse sensitivity, invert
      Y, key rebinding). Reachable from the main menu and the pause menu (M8).
- [x] **Keep pushing the art toward Sea of Thieves**, and a bit more detailed than now:
      hand-painted colour variation, stronger toon banding, more props and detail.
      *(A painted toon shader on everything opaque, and frames, cables, valves, lamp cages,
      extinguishers and room props through the boat. Ships and islands can keep going.)*
- [x] **Customisable characters that look like Sea of Thieves crew**: stylised, exaggerated
      proportions, with faces, hair, body shape, clothes and hats to choose from (builds on the
      M7 rank hats).
- [x] **Visible torpedo trails**: a bubble wake you can see from the periscope from launch
      to hit or miss.
- [x] **Navigation station**: a chart with each target at its last marked position and the
      land masses drawn in (builds on the M3 chart table).
- [x] **Islands and land masses** in the ocean world, which the boat has to steer around.
- [x] **Portholes** along the sides of the boat, showing the water and any ship hull on that
      side (overlaps Blaney's M8 portholes).
- [x] **Well-lit water like Sea of Thieves**: bright, clear and readable under the surface,
      not murky.
- [x] **Sea floor with reefs and mountains / shelves** the boat has to avoid (running into
      them damages it); pairs with Blaney's M8 coral reef.
- [x] **Sea life**: fish, sharks, whales and octopus. Whales show up on sonar as false
      contacts.
- [x] **Listening station**: hydrophone headphones where you hear ship engines and screws
      and animal sounds, and have to tell them apart.
- [x] **Music**: a soundtrack (menu, patrol, combat / being hunted), with its own volume in
      the settings menu.
- [x] **Third-person emotes**: the camera pulls out to third person while you play an emote
      (wave, salute, dance, ...) so you can see your own crewman.
- [x] **Rec room**: a compartment for whimsical fun and mini games, separate from the
      mission objectives. Matters most in the generative free-roam mode.
- [ ] **Modes on an arcade ↔ realism scale**: more modes and boats that set how arcadey or
      realistic it plays, from the arcade mode above up to a most-realistic mode. Includes the
      nuclear era, e.g. a full Typhoon-class boat with its exact deck layout as the most
      realistic.
      *(Started: Arcade / Standard / Realistic picked by the host (`Realism`): handling, duds,
      flooding, fires, air, escorts. Still to come: the nuclear-era boats.)*
- [x] **Sound effects for everything**: every control, station and action makes a sound. To
      start: a telegraph ding when the ordered speed changes, and the helm wheel and rudder
      gear sound as it turns. *(Every station, door, tool, footstep and ladder now has one;
      anything new gets its sound when it is made.)*
- [x] **Optional bot crew**: AI crewmen you assign to stations and either give orders to or
      leave to act on their own, to fill out a small crew.

## M10 — Finish the WW2 arcade mode (2026-10-30)
lando: "we can finish the current arcadey ww2 mode first". The nuclear-era boats wait until
then. What `docs/design.md` promises that wasn't built yet:
- [x] **Two on the hoist**: a crewmate standing by a tube makes its reload 1.7× quicker.
- [x] **Crouch** (hold Ctrl): lower, half speed, near-silent feet; crewmates see it.
- [x] **Torpedo tracks give the boat away**: a warship whose lookouts see a bubble track
      (1.5 km by day, less at night or in rough seas) comes down it toward where it was fired
      from, and sonar calls it. Merchants don't dodge a track (too harsh for arcade).
- [x] **The fixed bilge pump** in the control room: drains the wettest compartment 4× a
      portable pump, off the battery, loud enough for escorts to hear; it can break, and a bot
      pump man runs it while there's water aboard and stops it while hunted.


## M11 — Graphics pass and sprint (2026-10-30)
lando: "I want to greatly improve the graphics. Improve the shapes and textures of everything.
Also add a sprint functionality".
- [x] **Shapes**: every box has bevelled edges, cylinders are lathed with chamfered rims;
      the boat's hull curves at the shoulders and bilges, with curved ring frames; torpedoes
      are real Mark 14s (warhead, tail cone, fins, screws) in cradle straps.
- [x] **Ships**: lofted hulls (fine bow with flare and a raked stem, sheer, round bilges, a
      rounded stern and transom, raised forecastles and poops), a red bottom showing above
      the water, a dark rubbing strake; turrets on barbettes with sloped faces and tapered
      barrels, funnels with caps, window bands and overhanging roofs, masts with yards, ship's
      boats, portholes, hangar openings and elevators on the carrier.
- [x] **Textures**: 512 px detail maps with height maps; the toon shader bumps the light with
      them and darkens the hollows (seams, rivet rows, tread, plank joints, lapped strakes); a
      fine painted grain on every colour without its own map; woven cloth on the crew.
- [x] **Sky**: painted toon clouds with shaded bellies, drifting (more of them in rougher
      seas), a soft sun, stars at night.
- [x] **Sprint** (hold Shift, forward): 1.75× walking speed, the view widens and the head
      bobs, longer and louder footsteps that crewmates hear; not crouched, slower in foul air.
- [x] **Faces, ocean, islands, sea life** (lando: "do the faces, the ocean, the islands or the
      sea life"): eyes with a glint, lids, cheeks, jaw and smile, skin and hair textures; five
      waves, ripples, glowing crests, lace foam and sun glints; rock-textured islands thick with
      jungle, better palms, boulders; streamlined fish, sharks and whales.

## M12 — Deck gun and weather (2026-10-30)
lando: "add deck gun and weather to the roadmap".
- [x] **Deck gun**: a gun on the casing for fighting on the surface, crewed from inside (up
      the conning-tower hatch), against merchants and small escorts, with ammunition passed up.
      *(S-boat 4-inch, Gato 5-inch, Narwhal 6-inch. Mouse trains, the range is set on the sight
      (rangefinder on F), fall of shot to walk onto the target; a few ready rounds at the gun and
      the rest passed up the scuttle by a crewmate or bot; firing alerts every ship within 12 km
      and the escorts shoot back; diving clears the deck. Bot gunlayer and passer.)*
- [x] **Weather**: rain and squalls that roll across the patrol, cutting how far lookouts and
      the periscope see (cover to close in on a convoy), rougher seas and darker skies with them.
      *(Squalls drift with the wind, by sea state (a mission can set how many); in one, their
      lookouts and planes see a quarter as far, hydrophones hear less, our periscope sees a km or
      two; rain on the hull; the lookouts call it.)*
