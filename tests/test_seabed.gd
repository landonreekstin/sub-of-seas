extends RefCounted
## The sea floor: islands, reefs, seamounts; grounding, ships keeping off, torpedoes beaching.

const GATO := preload("res://data/subs/gato.tres")

var runner: Object


func _world() -> OceanWorld:
	var w := OceanWorld.new(GATO, 7)
	w.hull.setup([{"name": "forward torpedo room", "z0": -10.0, "z1": 0.0}, {"name": "b", "z0": 0.0, "z1": 10.0}], {"ab": [0, 1]}, {"helm": 0})
	return w


## A round island of radius `r` with its centre `dist` metres north of the origin.
func _island(dist: float, r := 1000.0) -> Dictionary:
	return {"kind": "island", "x": 0.0, "y": dist, "r": r, "top": -80.0, "reef": 6.0, "ang": 0.0, "stretch": 1.0, "h": []}


func test_island_profile() -> bool:
	var s := Seabed.new()
	s.features.append(_island(0.0))
	runner.check(s.floor_depth(Vector2.ZERO) < -70.0, "the island's peak is high and dry")
	runner.check(s.is_land(Vector2(0, 500)), "inside the coast is land")
	var reef := s.floor_depth(Vector2(0, 900))
	runner.check(reef > 0.0 and reef < 12.0, "a shallow reef flat off the beach (%.1f m)" % reef)
	runner.check(s.floor_depth(Vector2(0, 2500)) == Seabed.BASE, "deep ocean beyond it")
	return true


func test_generation_keeps_clear() -> bool:
	for seed_value in 20:
		var s := Seabed.new()
		var ship := Vector2(3000, 4000)
		s.generate(seed_value, Vector2.ZERO, [Vector2.ZERO, ship] as Array[Vector2], [[ship, ship + Vector2(-30000, 0)], [Vector2.ZERO, ship]])
		runner.check(not s.features.is_empty(), "seed %d: something on the floor" % seed_value)
		for p: Vector2 in [Vector2.ZERO, ship, ship + Vector2(-15000, 0), ship * 0.5]:
			if s.floor_depth(p) < 200.0:
				runner.check(false, "seed %d: shallow water at %s, on the boat's or a ship's track" % [seed_value, p])
	var a := Seabed.new()
	var b := Seabed.new()
	a.generate(5, Vector2.ZERO, [] as Array[Vector2], [])
	b.from_array(a.to_array())
	runner.check(is_equal_approx(a.floor_depth(Vector2(4000, 4000)), b.floor_depth(Vector2(4000, 4000))), "a client's copy matches the host's")
	return true


func test_running_aground_stops_and_holes_the_bow() -> bool:
	var w := _world()
	w.seabed.features.append(_island(1600.0))
	w.sub.depth = 0.0
	w.sub.ballast = 0.0
	w.sub.diesels.assign([1.0, 1.0])
	w.sub.telegraph = 4
	w.sub.speed = w.sub.max_speed()
	var events: Array[Dictionary] = []
	w.event.connect(func(k: String, d: Dictionary) -> void:
		if k == "grounded":
			events.append(d))
	for i in 600:
		w.step(0.25)
	runner.check(not w.seabed.is_land(w.sub.pos), "she never gets onto the island")
	runner.check(w.seabed.floor_depth(w.sub.pos) >= SubState.AWASH_DEPTH - 0.01, "she stops at the reef's edge (%.1f m)" % w.seabed.floor_depth(w.sub.pos))
	runner.check(not events.is_empty() and events[0].hard, "a hard grounding is announced")
	runner.check(not w.hull.leaks.is_empty() and int(w.hull.leaks[0].c) == 0, "and opens a leak forward")
	return true


func test_diving_onto_a_seamount_sits_on_the_bottom() -> bool:
	var w := _world()
	w.seabed.features.append({"kind": "seamount", "x": 0.0, "y": 0.0, "r": 800.0, "top": 40.0, "reef": 0.0, "ang": 0.0, "stretch": 1.0, "h": []})
	w.sub.depth = 30.0
	w.sub.ballast = 1.0
	w.sub.ordered_depth = 90.0
	for i in 400:
		w.step(0.25)
	runner.check(w.sub.depth <= 40.0 and w.sub.depth > 35.0, "she rests on the peak at %.1f m" % w.sub.depth)
	runner.check(w.hull.leaks.is_empty(), "settling gently does no damage")
	return true


func test_ships_steer_round_an_island() -> bool:
	var w := _world()
	w.seabed.features.append(_island(6000.0, 1200.0))
	w.sub.pos = Vector2(-20000, 0)
	var ship := ShipState.new(Formations.ship_class("freighter"))
	ship.id = 99
	w.ships.append(ship)
	ship.course = 0.0
	ship.base_course = 0.0
	ship.heading = 0.0
	ship.ordered_speed = 6.0
	ship.speed = 6.0
	var closest := INF
	for i in 6000:
		w.step(0.25)
		closest = minf(closest, w.seabed.floor_depth(ship.pos))
	runner.check(closest >= ShipState.DRAFT, "the freighter never got into water shallower than her draft (%.1f m)" % closest)
	runner.check(ship.pos.y > 8000.0, "and still got past it (y %.0f)" % ship.pos.y)
	return true


func test_torpedo_beaches_on_an_island() -> bool:
	var w := _world()
	w.seabed.features.append(_island(1500.0))
	w.sub.depth = 18.0
	var beached: Array[bool] = [] # lambdas capture locals by value; an array is shared
	w.event.connect(func(k: String, _d: Dictionary) -> void:
		if k == "beached":
			beached.append(true))
	w.fire_torpedo(0.0)
	for i in 400:
		w.step(0.25)
	runner.check(not beached.is_empty() and w.torpedoes.is_empty(), "the torpedo stops at the shore")
	return true
