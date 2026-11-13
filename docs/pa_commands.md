# PA commands

Every order the crew understand on the PA microphone. To use it, press E at the mic (control room,
after bulkhead, port of the door), type, and press Enter. The Typhoon's mic is in the command bay.
You don't have to use these exact words: the crew pick out the key words, so "take her down to 60
metres" works as well as "dive to 60". Join orders with "and" or "then": "come to 090 and full
speed", "surface then open fire".

Orders go to bot crewmen. A friend at that station gets the order on his screen instead, and the
crew say who has it. If nobody is at a station, a bot is posted to it. The same list is on the PA
panel in the game, and the tests check that every line here works (`CrewCommand.HELP`).

## Moving
| Say | What happens |
|---|---|
| "full speed", "flank", "fast" | Engines full ahead |
| "standard speed", "cruise" | Standard speed |
| "half speed" | Half ahead |
| "slow ahead", "slow down", "quiet" | Slow ahead: quieter, easier on the battery |
| "stop", "halt" | All stop |
| "back", "reverse" | Back the engines |
| "faster" / "slower" | One step up or down on the engine telegraph |
| "come to 090", "steer 270", "heading 180" | Steer to that compass course |
| "head north" (east, southwest, ...) | Steer that way |
| "turn left" / "turn right", "turn to port" / "turn to starboard" | 45° that way ("turn left 20" for 20°) |
| "hard right", "hard left" | 90° that way |
| "turn around", "come about" | Turn round the other way |
| "head for the island", "go to land" | Steer for the nearest land |

## Places to go
The crew steer there themselves (round islands and shoals), full ahead when far off, slowing as
they close, and say when they're there. A place on the sea floor: the planesman takes her down to
look at it, 15 m above it, and she stops over it.
| Say | What happens |
|---|---|
| "take us to the wreck", "go to the shipwreck" | The wreck of the Kiyo Maru |
| "go to the ruins", "the temple" | The drowned temple |
| "explore the vents", "the smokers" | The black smokers: glowing vents |
| "visit the garden", "the coral" | The glowing garden |
| "take us to the crystal city", "the aliens" | The crystal city, the deepest of them |
| "go to the island" | The nearest island (each has a name on the chart) |
| "take us to the cave" | The cave's near mouth (then "take us through the cave") |
| "list places", "where can we go" | Every place on the chart, nearest first, its bearing and range |
| "clear the waypoint" | Forget it |

## Up and down
| Say | What happens |
|---|---|
| "dive", "dive dive", "submerge" | Down to a normal depth |
| "dive to 60", "depth 45 metres" | Down (or up) to that many metres |
| "periscope depth" | Just under, with the scope able to see out |
| "take her deep", "test depth" | As deep as she is built to go |
| "go deeper" / "go up", "shallower", "rise" | 20 m down or up |
| "dive to the bottom", "the sea floor" | Down to just above the bottom |
| "surface", "emerge" | Up to the surface, tanks blown, hatch can open |
| "crash surface", "emergency surface", "breach" | Emergency blow: she shoots up and breaches |

## Fighting
| Say | What happens |
|---|---|
| "sink the ship to the east" | The crew pick the ship that way and attack it: close in, aim, fire |
| "attack the carrier" (freighter, tanker, battleship, cruiser, destroyer, escort, sub chaser, ...) | Go after that kind of ship |
| "sink the destroyer to the north" | That kind of ship, in that direction |
| "fire torpedoes", "attack", "sink something" | Attack whatever ship is best |
| "reload" | Torpedomen to every empty tube |
| "open fire", "man the gun" | Gun crew up on deck and shooting (surfaced only) |
| "enemy sub" | An enemy submarine comes hunting you |
| "attack the enemy sub" | And the crew go after it |
| "belay that", "cancel", "cease fire", "abort" | Stop what they're doing |

## Getting away
| Say | What happens |
|---|---|
| "get us out of here", "evade", "run", "hide", "lose them" | Deep under the layer, slow and quiet, away from the hunters |
| "silent running" | The same |

## The crew
| Say | What happens |
|---|---|
| "battle stations", "man the stations" | A crewman at every watch station |
| "all hands on deck" | Every post manned, the boat full of men, damage parties ready, and the crew do the patrol's job on their own (sink the targets, or take her through the cave) until "stand down" |
| "take us through the cave", "go through the tunnel" | The crew steer her into the near end of the cave and out of the far one, slow, holding her in the middle |
| "fix the damage", "repair", "put out the fire", "pump out the water" | Damage parties to the leaks, fires and broken gear |
| "fresh air", "oxygen", "scrubber" | A crewman at the air station keeping it breathable |
| "stand down", "at ease", "dismissed" | Every bot leaves his station |

## Asking
| Say | What happens |
|---|---|
| "report", "status", "what's wrong", "damage report" | The worst problem aboard, and how many more there are |
| "what's out there", "contacts", "what do you hear" | What sonar and the lookouts know of |
| "what's our objective", "what are we doing", "orders" | The patrol's orders and how far along they are |

## For fun
| Say | What happens |
|---|---|
| "god mode" (again to turn it off; "god mode on" / "god mode off") | For whoever says it: three times as fast on foot, eight times in the sea (Shift for sixteen) to catch a boat and watch her from outside, and nothing knocks you out (bad air, too deep). Just for you, not the crew |
| "band play", "music", "play a song" | The ship's band strikes up |
| "stop the music" | And stops |
| "spawn a kraken", "giant squid" | A kraken comes up out of the deep |
| "megalodon", "shark" | A megalodon |
| "sea serpent", "eel" | A sea serpent |
| "anglerfish" | A giant anglerfish |
| "monster", "leviathan" | Any one of them |
