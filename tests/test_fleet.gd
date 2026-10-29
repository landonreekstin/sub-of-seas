extends RefCounted
## Ship classes, formations, gunfire and mission data.

const GATO := preload("res://data/subs/gato.tres")

var runner: Object


func _world() -> OceanWorld:
	var w := OceanWorld.new(GATO, 5)
	w.hull.setup([{"name": "a", "z0": -10.0, "z1": 0.0}, {"name": "b", "z0": 0.0, "z1": 10.0}], {"ab": [0, 1]}, {"helm": 0})
	w.sub.depth = 45.0
	w.sub.ordered_depth = 45.0
	w.sub.ballast = 1.0
	return w


func _run(w: OceanWorld, seconds: float, dt := 0.25) -> void:
	for i in int(seconds / dt):
		w.step(dt)


func test_every_ship_class_loads_and_builds() -> bool:
	for k in ["freighter", "tanker", "carrier", "battleship", "cruiser", "destroyer", "kaibokan", "subchaser"]:
		var d := Formations.ship_class(k)
		runner.check(d != null and d.key == k, "%s data" % k)
		var model := ShipModels.build(d)
		runner.check(model.get_child_count() > 5, "%s model has parts" % k)
		model.free()
	return true


func test_convoy_zigzags_together() -> bool:
	var w := _world()
	w.sub.pos = Vector2(0, -30000) # far away: nobody is alerted
	var ships := Formations.convoy(w, Vector2.ZERO, 270.0, 8.0, ["freighter", "tanker", "freighter", "freighter"], ["destroyer"])
	_run(w, 900.0)
	var lead := ships[0]
	var spread := 0.0
	for s in ships:
		spread = maxf(spread, s.pos.distance_to(lead.pos))
	runner.check(lead.pos.x < -3000.0, "convoy steamed west: %.0f" % lead.pos.x)
	runner.check(spread < 3000.0, "still in formation after 15 min: spread %.0f m" % spread)
	return true


func test_surfaced_boat_near_an_alert_destroyer_gets_shelled() -> bool:
	var w := _world()
	w.sub.depth = 0.0
	w.sub.ordered_depth = 0.0
	w.sub.ballast = 0.0
	var dd := w.add_ship(Formations.ship_class("destroyer"), Vector2(0, 3000), 180.0, 10.0)
	dd.alert()
	var shells := []
	w.event.connect(func(k: String, d: Dictionary) -> void:
		if k == "shell" or (k == "blast" and d.get("shell", false)):
			shells.append(k))
	_run(w, 60.0)
	runner.check(shells.size() >= 5, "salvoes fired: %d" % shells.size())
	runner.check(shells.has("blast"), "and some hit")
	return true


func test_no_shelling_when_submerged() -> bool:
	var w := _world()
	var dd := w.add_ship(Formations.ship_class("destroyer"), Vector2(0, 3000), 180.0, 10.0)
	dd.alert()
	var shells := []
	w.event.connect(func(k: String, _d: Dictionary) -> void:
		if k == "shell":
			shells.append(k))
	_run(w, 60.0)
	runner.check(shells.is_empty(), "guns can't reach her at 45 m")
	return true


func test_small_charges_do_less_damage() -> bool:
	var big := _world()
	var small := _world()
	big.drop_charge(big.sub.pos + Vector2(10, 0), big.sub.depth, 1.0)
	small.drop_charge(small.sub.pos + Vector2(10, 0), small.sub.depth, 0.5)
	_run(big, 20.0)
	_run(small, 20.0)
	var big_rate := 0.0
	for l in big.hull.leaks:
		big_rate += l.rate
	var small_rate := 0.0
	for l in small.hull.leaks:
		small_rate += l.rate
	runner.check(big_rate > small_rate, "a big charge at 10 m holes her worse (%.2f vs %.2f)" % [big_rate, small_rate])
	return true


func test_hunter_killer_sweeps_and_pings() -> bool:
	var w := _world()
	w.sub.pos = Vector2(0, -20000)
	var group := Formations.hunter_killer(w, Vector2.ZERO, 0.0, ["subchaser", "kaibokan"], 3000.0)
	var pings := []
	w.event.connect(func(k: String, _d: Dictionary) -> void:
		if k == "ping":
			pings.append(k))
	var start := group[1].pos
	_run(w, 300.0)
	runner.check(pings.size() > 20, "the group pings while sweeping: %d" % pings.size())
	runner.check(group[1].pos.distance_to(start) > 1000.0, "and moves")
	return true


func test_every_mission_loads_and_spawns() -> bool:
	for k in MissionData.KEYS:
		var m := MissionData.load_key(k)
		runner.check(m != null and m.key == k and m.title != "" and not m.objectives.is_empty(), "mission %s loads" % k)
		var w := _world()
		var n := 0
		for g: Dictionary in m.groups:
			n += Formations.spawn(w, g).size()
		runner.check(n > 0 and w.ships.size() == n, "mission %s spawns %d ships" % [k, n])
		_run(w, 30.0)
	return true
