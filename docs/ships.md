# Ships — historical reference and game values

Historical numbers are approximate, from common references on the classes. Game values are
scaled for fun and live in `data/ships/*.tres` / `data/subs/*.tres`; when they differ from
history it is on purpose. HP is in "torpedo hits" (one Mk 14 warhead ≈ 1.0) before damage
model details (flooding, list, magazine hits) come into it.

## Enemy surface ships (IJN, 1942–44)

| Class (example) | Displ. (t) | Max speed | Anti-sub kit (historical) | Game HP | Game threat |
|---|---|---|---|---|---|
| Freighter (Maru) | 3–8,000 GRT | 9–14 kn | none / one deck gun | 1.5–2 | none |
| Tanker | 10,000 | 13–16 kn | none | 2.5 (burns) | none |
| Fleet carrier (*Shōkaku*) | 32,000 | 34 kn | none; aircraft | 7 | via escorts, aircraft (M7) |
| Battleship (*Kongō*) | 32,000 | 30 kn | none vs submerged | 8 | surface guns only |
| Heavy cruiser (*Takao*) | 15,000 | 35 kn | a few DCs, floatplanes | 4 | low |
| Destroyer (*Kagerō*) | 2,500 | 35 kn | hydrophones + active sonar, ~16–36 DCs, 2 throwers + racks | 1.5 | very high |
| Escort (*Kaibōkan*, Type C/D) | 750–940 | 16.5–17.5 kn | type 93 sonar, 120 DCs, 12 throwers | 1.2 | high |
| Sub-chaser (Type 13) / motor torpedo boat | 440 / 20–80 | 16–35 kn | light DCs | 0.5 | medium, great spotter |

Depth-charge (Type 95): ~100 kg charge, sinks ~2–3 m/s, settable to 30–150 m. Game: lethal
radius ~8 m, heavy damage ~20 m, shake ~60 m, falloff with distance.

## US submarines (player)

| Class | Surf. displ. | Surf / sub speed | Test depth | Tubes | Torpedoes | Crew (hist.) | Game crew |
|---|---|---|---|---|---|---|---|
| S-class (S-42) | 900 t | 14.5 / 11 kn | 61 m | 4 bow | 12 | 42 | 3–4 |
| Gato-class | 1,525 t | 21 / 9 kn | 91 m | 6 bow + 4 stern | 24 | 60–80 | 4–6 |
| Narwhal-class | 2,730 t | 17 / 8 kn | 91 m | 4 bow + 2 stern (+ 4 deck tubes) | 40 | 90 | 6–8 |

Game Narwhal gets 6 bow + 4 stern tubes for playability (the deck tubes were external and
fixed; folding them into the internal count is simpler than a separate system).

## Mk 14 torpedo

46 kn on high speed, ~4,100 m range; early war ran ~3 m deep and had exploder faults. Game:
46 kn, 4,000 m, configurable dud/deep-run chance (default 5 %), wake visible.
