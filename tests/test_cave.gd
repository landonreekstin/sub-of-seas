extends RefCounted
## The cave challenge: an S-bend tunnel through a ridge. Every boat fits through it held in the
## middle, and scrapes or stops when she isn't.

const SUBS := ["s_boat", "gato", "narwhal", "typhoon", "titan"]

var runner: Object


func _world(key: String) -> OceanWorld:
	var data: SubClassData = load("res://data/subs/%s.tres" % key)
	var w := OceanWorld.new(data, 3)
	w.hull.setup([{"name": "bow room", "z0": -10.0, "z1": 0.0}, {"name": "stern room", "z0": 0.0, "z1": 10.0}], {"ab": [0, 1]}, {"helm": 0})
	return w


## A cave running north, its way in 400 m north of the start.
func _cave(w: OceanWorld) -> Dictionary:
	var d := w.sub.data
	return w.seabed.add_cave(Vector2(0, 750), PI * 0.5, Seabed.cave_size(d.length, d.beam, d.height, d.test_depth))


func _mid(f: Dictionary, w: OceanWorld, u: float) -> float:
	return (Seabed.cave_roof(f, u) + w.sub.data.height + Seabed.cave_bottom(f, u)) * 0.5


## Held to the tunnel's middle line and halfway between roof and floor, she goes through clean.
func test_every_boat_fits_through_held_in_the_middle() -> bool:
	for key: String in SUBS:
		var w := _world(key)
		var f := _cave(w)
		runner.check(w.seabed.floor_depth(Vector2(0, 750)) > 0.0 and w.seabed.roof_depth(Vector2(0, 750)) > 0.0, "%s: the tunnel's middle is water under a roof" % key)
		runner.check(w.seabed.is_land(Vector2(300, 750)), "%s: beside the tunnel is rock above the water" % key)
		w.sub.ballast = 1.0
		w.sub.telegraph = 2
		w.sub.speed = 3.0
		var scrapes := []
		w.event.connect(func(k: String, d: Dictionary) -> void:
			if k == "grounded":
				scrapes.append(d.text))
		for i in 2400:
			var c := Seabed.cave_local(f, w.sub.pos)
			var u := clampf(c.x, -350.0, 350.0)
			var aim := Seabed.cave_world(f, Vector2(u + 20.0, Seabed.cave_centre(f, u + 20.0)))
			w.sub.heading = ShipState.bearing(w.sub.pos, aim) if c.x < 360.0 + w.sub.data.length else 0.0
			w.sub.rudder = 0.0
			w.sub.depth = _mid(f, w, u)
			w.sub.ordered_depth = w.sub.depth
			w.sub.speed = 3.0
			w.step(0.25)
			if w.caves_through > 0:
				break
		runner.check(w.caves_through == 1, "%s: through and out the far end (%d)" % [key, w.caves_through])
		runner.check(scrapes.is_empty(), "%s: not a scrape on her (%s)" % [key, scrapes])
	return true


func test_shallow_into_the_ridge_stops_her() -> bool:
	var w := _world("gato")
	_cave(w)
	w.sub.depth = 0.0
	w.sub.ballast = 0.0
	w.sub.telegraph = 4
	w.sub.speed = 6.0
	var hits := []
	w.event.connect(func(k: String, d: Dictionary) -> void:
		if k == "grounded":
			hits.append(d))
	for i in 800:
		w.step(0.25)
	runner.check(w.sub.pos.y < 400.0 + 1.0, "she never gets into the ridge (%.0f)" % w.sub.pos.y)
	runner.check(not hits.is_empty(), "hitting it is announced")
	runner.check(w.cave_scrapes > 0, "and counted")
	return true


func test_running_straight_hits_a_wall_or_roof() -> bool:
	var w := _world("gato")
	var f := _cave(w)
	w.sub.ballast = 1.0
	w.sub.depth = _mid(f, w, -350.0)
	w.sub.ordered_depth = w.sub.depth
	w.sub.telegraph = 3
	w.sub.speed = 4.0
	for i in 1200:
		w.step(0.25)
	runner.check(w.cave_scrapes > 0, "straight and level, she hits the bend or the roof")
	runner.check(w.caves_through == 0, "and doesn't get through on her own")
	return true


func test_ships_and_torpedoes_dont_pass_the_ridge() -> bool:
	var w := _world("gato")
	_cave(w)
	runner.check(w.seabed.clear_course(Vector2(0, 0), 0.0, 8.0, 2000.0) != 0.0, "a ship won't steer over the tunnel's roof")
	runner.check(w.seabed.roof_depth(Vector2(0, 750)) > 0.0 and w.seabed.roof_depth(Vector2(0, 200)) == 0.0, "the roof is only over the tunnel")
	return true


## The Titan (Blaney: too deep she cracks and warns first, then implodes).
func test_the_titan_holds_at_her_rating_cracks_past_it_then_implodes() -> bool:
	var w := _world("titan")
	w.seabed.features.append({"kind": "trench", "x": 0.0, "y": 0.0, "r": 4000.0, "top": 5500.0, "reef": 0.0, "ang": 0.0, "stretch": 1.0, "h": []})
	w.sub.ballast = 1.0
	w.sub.depth = 3900.0
	w.sub.ordered_depth = 3900.0
	var cracks: Array[int] = []
	var gone := []
	w.event.connect(func(k: String, d: Dictionary) -> void:
		if k == "crack":
			cracks.append(int(d.level))
		elif k == "implode":
			gone.append(true))
	for i in 400:
		w.step(0.25)
	runner.check(w.hull_strain == 0.0 and w.lost == "", "inside her rating she's sound")
	runner.check(w.hull.leaks.is_empty(), "a carbon hull never leaks")
	w.sub.depth = 4500.0
	w.sub.ordered_depth = 4500.0
	for i in 2000:
		w.step(0.25)
		if w.lost != "":
			break
	runner.check(cracks == [1, 2, 3], "the hull monitor calls out three warnings first (%s)" % [cracks])
	runner.check(w.lost.contains("imploded") and gone.size() == 1, "then she implodes (%s)" % w.lost)
	var back := _world("titan")
	back.apply_snapshot(w.to_snapshot())
	runner.check(is_equal_approx(back.hull_strain, w.hull_strain), "the strain reaches every crewman's screen")
	return true
