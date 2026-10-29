class_name Sandbox
extends RefCounted
## The open-ocean patrol: keeps a few groups of ships moving through the area, spawning new
## ones out of sight on courses that pass near the boat and letting ones that are far gone go.
## Day and night take turns every 15 minutes. Host only.

const WANT_GROUPS := 2
const SPAWN_MIN := 11000.0
const SPAWN_MAX := 15000.0
const FORGET := 30000.0 ## ships this far from the boat leave the sim
const DAY_LENGTH := 900.0
## Weighted group table: [weight, type, ships, escorts, speed kn].
const GROUPS := [
	[30, "convoy", ["freighter", "freighter", "freighter"], ["destroyer"], 8.0],
	[15, "convoy", ["freighter", "tanker", "freighter", "freighter"], ["kaibokan", "destroyer"], 8.0],
	[15, "convoy", ["tanker", "tanker"], ["kaibokan"], 10.0],
	[10, "task_force", ["cruiser"], ["destroyer", "destroyer"], 18.0],
	[8, "task_force", ["carrier"], ["destroyer", "destroyer"], 20.0],
	[5, "task_force", ["battleship"], ["destroyer", "destroyer", "destroyer"], 18.0],
	[17, "hunter_killer", ["subchaser", "subchaser"], [], 0.0],
]

var _timer := 5.0
var _groups: Array = [] ## Array of Array[ShipState]


func tick(world: OceanWorld, dt: float) -> void:
	var c := world.conditions
	var night := fmod(world.time, DAY_LENGTH * 2.0) >= DAY_LENGTH
	if night != c.night:
		c.night = night
		world.event.emit("power", {"text": "Night falls. Rig for red." if night else "Dawn."})
	_timer -= dt
	if _timer > 0.0:
		return
	_timer = 30.0
	var sub := world.sub
	var gone := world.ships.filter(func(s: ShipState) -> bool: return s.pos.distance_to(sub.pos) > FORGET)
	for s: ShipState in gone:
		world.ships.erase(s)
	_groups = _groups.filter(func(g: Array) -> bool:
		return g.any(func(s: ShipState) -> bool: return world.ships.has(s) and not s.is_sinking()))
	if _groups.size() < WANT_GROUPS:
		_groups.append(spawn_group(world))


## A group out of sight on a course that passes within a few km of the boat.
func spawn_group(world: OceanWorld) -> Array[ShipState]:
	var rng := world.rng
	var total := 0
	for g: Array in GROUPS:
		total += int(g[0])
	var roll := rng.randi() % total
	var pick: Array = GROUPS[0]
	for g: Array in GROUPS:
		roll -= int(g[0])
		if roll < 0:
			pick = g
			break
	var sub := world.sub.pos
	var at := sub + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(SPAWN_MIN, SPAWN_MAX)
	var aim := sub + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1500.0, 5000.0)
	var spec := {"type": pick[1], "ships": pick[2], "escorts": pick[3], "pos": at,
		"course": ShipState.bearing(at, aim), "speed": pick[4], "radius": 4000.0}
	if pick[1] == "hunter_killer":
		spec.pos = sub + (at - sub) * 0.5 # hunting groups sweep closer in
	return Formations.spawn(world, spec)
