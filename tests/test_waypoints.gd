extends RefCounted
## Places to go (sim/places.gd), the sea-floor sites (Seabed.add_sites) and the waypoint the
## crew steer to by themselves (BotCrew.waypoint_wants).

var runner: Object


func _world(key := "gato") -> OceanWorld:
	var data: SubClassData = load("res://data/subs/%s.tres" % key)
	var w := OceanWorld.new(data, 3)
	w.hull.setup([{"name": "bow room", "z0": -10.0, "z1": 0.0}, {"name": "stern room", "z0": 0.0, "z1": 10.0}], {"ab": [0, 1]}, {"helm": 0})
	return w


func test_every_boat_gets_every_site_within_reach() -> bool:
	for key: String in ["s_boat", "gato", "typhoon", "titan"]:
		var w := _world(key)
		var keep: Array[Vector2] = [Vector2.ZERO]
		w.seabed.add_sites(7, Vector2.ZERO, w.sub.data.test_depth, keep, [])
		var sites := w.seabed.sites()
		runner.check(sites.size() == Seabed.SITES.size(), "%s: one of each site (%d)" % [key, sites.size()])
		for f in sites:
			var floor_at := w.seabed.floor_depth(Vector2(f.x, f.y))
			runner.check(absf(floor_at - float(f.top)) < 1.0, "%s: %s's floor is at its depth (%.0f vs %.0f)" % [key, f.type, floor_at, f.top])
			runner.check(float(f.top) - BotCrew.SITE_LOOK - w.sub.data.height <= w.sub.data.test_depth and float(f.top) > w.sub.data.height + 8.0, "%s: she can get down to look at %s, and over it" % [key, f.type])
			var d := Vector2(f.x, f.y).length()
			runner.check(d > 2500.0 and d < 15000.0, "%s: %s is a trip away, not on top of us (%.0f m)" % [key, f.type, d])
		var garden: Dictionary = sites.filter(func(f: Dictionary) -> bool: return f.type == "garden")[0]
		var alien: Dictionary = sites.filter(func(f: Dictionary) -> bool: return f.type == "alien")[0]
		runner.check(float(alien.top) > float(garden.top), "%s: the crystal city is deeper than the garden" % key)
	return true


func test_places_list_and_nearest() -> bool:
	var w := _world()
	w.seabed.features.append({"kind": "island", "x": 0.0, "y": 5000.0, "r": 1000.0, "top": -80.0, "reef": 6.0, "ang": 0.0, "stretch": 1.0, "h": []})
	var keep: Array[Vector2] = [Vector2.ZERO]
	w.seabed.add_sites(3, Vector2.ZERO, 90.0, keep, [])
	var all := Places.by_distance(w.seabed, Vector2.ZERO)
	runner.check(all.size() == 6, "five sites and an island (%d)" % all.size())
	runner.check(Places.pos(all[0]).length() <= Places.pos(all[-1]).length(), "nearest first")
	runner.check(Places.nearest(w.seabed, Vector2.ZERO, "island").name == Places.ISLANDS[0], "the island has a name")
	runner.check(Places.nearest(w.seabed, Vector2.ZERO, "alien").kind == "alien", "the crystal city is on the list")
	runner.check(Places.nearest(w.seabed, Vector2.ZERO, "volcano").is_empty(), "nothing that isn't there")
	return true


## Steered as the bot helmsman does, she goes round an island in the way and gets there.
func test_she_steers_round_an_island_to_the_waypoint() -> bool:
	var w := _world()
	w.seabed.features.append({"kind": "island", "x": 0.0, "y": 3000.0, "r": 800.0, "top": -80.0, "reef": 6.0, "ang": 0.0, "stretch": 1.0, "h": []})
	var wp := {"name": "far side", "x": 0.0, "y": 6500.0, "depth": -1.0}
	w.sub.heading = 0.0
	var grounded := []
	w.event.connect(func(k: String, d: Dictionary) -> void:
		if k == "grounded":
			grounded.append(d.text))
	var arrived := false
	for i in 8000:
		var want := BotCrew.waypoint_wants(w, wp)
		if float(want.range) < BotCrew.ARRIVE:
			arrived = true
			break
		var err := wrapf(float(want.course) - w.sub.heading, -180.0, 180.0)
		w.sub.rudder = 0 if absf(err) < 1.5 else clampi(int(signf(err)) * maxi(1, roundi(absf(err) / 8.0)), -3, 3)
		w.sub.telegraph = int(want.speed)
		w.sub.battery = 1.0 # the diesels' job, not this test's
		w.step(0.25)
	runner.check(arrived, "she reaches the waypoint (%.0f m off)" % Vector2(wp.x, wp.y).distance_to(w.sub.pos))
	runner.check(grounded.is_empty(), "without running onto the island (%s)" % [grounded])
	return true


## To a sea-floor place she goes all the way, to stop right over it (Blaney: "very close to it
## so that you can see what's going on from the outside cameras").
func test_she_stops_right_over_a_site() -> bool:
	var w := _world()
	var wp := {"name": "the wreck", "x": 300.0, "y": 2500.0, "depth": 60.0}
	w.sub.heading = 0.0
	var arrived := false
	for i in 8000:
		var want := BotCrew.waypoint_wants(w, wp)
		if float(want.range) < BotCrew.SITE_ARRIVE:
			arrived = true
			break
		var err := wrapf(float(want.course) - w.sub.heading, -180.0, 180.0)
		w.sub.rudder = 0 if absf(err) < 1.5 else clampi(int(signf(err)) * maxi(1, roundi(absf(err) / 8.0)), -3, 3)
		w.sub.telegraph = int(want.speed)
		w.sub.battery = 1.0
		w.step(0.25)
	runner.check(arrived, "she gets within %d m of it (%.0f m off)" % [roundi(BotCrew.SITE_ARRIVE), Vector2(wp.x, wp.y).distance_to(w.sub.pos)])
	return true


## Over a sea-floor site, the planes take her down to just above it.
func test_down_to_look_at_a_site() -> bool:
	var w := _world()
	var wp := {"name": "the wreck", "x": 0.0, "y": 1500.0, "depth": 60.0}
	var want := BotCrew.waypoint_wants(w, wp)
	runner.check(is_equal_approx(float(want.depth), maxf(60.0 - BotCrew.SITE_LOOK - w.sub.data.height, w.sub.data.periscope_depth)), "down to look at her (%.0f)" % want.depth)
	wp.y = 9000.0
	runner.check(is_equal_approx(float(BotCrew.waypoint_wants(w, wp).depth), 0.0), "far off with nobody about, she runs up on the diesels")
	var s := ShipState.new(load("res://data/ships/freighter.tres"))
	s.pos = Vector2(0, 3000)
	w.ships.append(s)
	runner.check(float(BotCrew.waypoint_wants(w, wp).depth) < 0.0, "with a ship about, she stays down")
	return true
