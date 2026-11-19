class_name Places
extends RefCounted
## Everywhere the boat can be sent (Blaney: "waypoints and places to travel to: click on the chart,
## a list of places, the PA"): the sea-floor sites, each island and the cave. Each place is
## {name, kind, x, y, depth}: depth is how far down a site's floor is (-1 for anything else).
## No rendering, so it is unit-tested.

const ISLANDS := ["Kaimana Island", "Tavake Island", "Moku Reef", "Pele Atoll", "Hina Island", "Ono Island", "Lono Island"]
## Words that name a kind of place, for the PA.
const WORDS := {"wreck": "wreck", "shipwreck": "wreck", "wreckage": "wreck", "ruins": "ruins", "ruin": "ruins", "temple": "ruins",
	"vents": "vents", "vent": "vents", "smokers": "vents", "smoker": "vents", "garden": "garden", "gardens": "garden", "coral": "garden",
	"alien": "alien", "aliens": "alien", "crystal": "alien", "city": "alien", "civilization": "alien", "civilisation": "alien",
	"island": "island", "islands": "island", "atoll": "island", "reef": "island", "cave": "cave", "tunnel": "cave"}


static func list(seabed: Seabed) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var islands := 0
	for f: Dictionary in seabed.features:
		match f.kind:
			"site":
				out.append({"name": str(f.name), "kind": str(f.type), "x": float(f.x), "y": float(f.y), "depth": float(f.top)})
			"island":
				out.append({"name": ISLANDS[islands % ISLANDS.size()], "kind": "island", "x": float(f.x), "y": float(f.y), "depth": -1.0})
				islands += 1
			"cave": # the way in nearest the middle of the patrol: its western/southern mouth
				var mouth := Seabed.cave_world(f, Vector2(-float(f.len) * 0.5 - 300.0, 0.0))
				out.append({"name": "the cave", "kind": "cave", "x": mouth.x, "y": mouth.y, "depth": -1.0})
	return out


## The places nearest `from` first.
static func by_distance(seabed: Seabed, from: Vector2) -> Array[Dictionary]:
	var out := list(seabed)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return Vector2(a.x, a.y).distance_to(from) < Vector2(b.x, b.y).distance_to(from))
	return out


## The nearest place of that kind ("" is any), or empty.
static func nearest(seabed: Seabed, from: Vector2, kind: String) -> Dictionary:
	for p in by_distance(seabed, from):
		if kind == "" or p.kind == kind:
			return p
	return {}


## A place's spot in the sea.
static func pos(p: Dictionary) -> Vector2:
	return Vector2(float(p.x), float(p.y))
