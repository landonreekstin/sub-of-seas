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
		runner.check(m != null and m.key == k and m.title != "" and (m.sandbox or not m.objectives.is_empty()), "mission %s loads" % k)
		if m.sandbox:
			continue # ships come later, from the Sandbox director
		var w := _world()
		var n := 0
		for g: Dictionary in m.groups:
			n += Formations.spawn(w, g).size()
		runner.check(n > 0 and w.ships.size() == n, "mission %s spawns %d ships" % [k, n])
		_run(w, 30.0)
	return true


func test_every_boat_builds_with_all_its_stations() -> bool:
	for k in ["s_boat", "gato", "narwhal"]:
		var data: SubClassData = load("res://data/subs/%s.tres" % k)
		var interior := SubInterior.create(data)
		interior.build()
		var tubes := interior.stations.keys().filter(func(s: String) -> bool: return s.begins_with("tube_")).size()
		runner.check(tubes == data.bow_tubes + data.stern_tubes, "%s: %d tubes" % [k, tubes])
		for sid in ["helm", "dive", "ballast", "periscope", "tdc", "sonar", "nav", "engine", "air"]:
			runner.check(interior.stations.has(sid), "%s has %s" % [k, sid])
		runner.check(interior.doors.size() == interior.compartments.size() - 1, "%s: a door in every inner bulkhead" % k)
		runner.check(interior.station_compartments().size() == interior.stations.size(), "%s: every station is inside a compartment" % k)
		runner.check(interior.racks.has("control") and interior.spawn_points.size() == 6, "%s: rack and spawn points" % k)
		runner.check(data.roles.size() >= data.crew_max, "%s: a suggested role for every crewman" % k)
		interior.free()
	return true


func test_night_and_the_layer_hide_the_boat() -> bool:
	var dd := ShipState.new(Formations.ship_class("destroyer"))
	dd.pos = Vector2(0, 1500)
	var sub := SubState.new(load("res://data/subs/gato.tres"))
	sub.depth = 18.0
	sub.periscope_raised = true
	var day := Conditions.new()
	Detection.conditions = day
	var seen_day := Detection.awareness_gain(dd, sub)
	var night := Conditions.new()
	night.night = true
	Detection.conditions = night
	runner.check(Detection.awareness_gain(dd, sub) < seen_day, "harder to see a scope at night")
	sub.depth = 80.0
	sub.periscope_raised = false
	Detection.conditions = day
	var ping_day := Detection.ping_chance(dd, sub)
	var layered := Conditions.new()
	layered.layer_depth = 60.0
	Detection.conditions = layered
	runner.check(Detection.ping_chance(dd, sub) < ping_day * 0.5, "the layer bounces their sonar")
	Detection.conditions = Conditions.new()
	return true


func test_carrier_planes_find_a_surfaced_boat_and_bomb() -> bool:
	var w := _world()
	w.sub.depth = 0.0
	w.sub.ordered_depth = 0.0
	w.sub.ballast = 0.0
	w.add_ship(Formations.ship_class("carrier"), Vector2(0, 8000), 90.0, 0.0).passive = true
	var seen := []
	w.event.connect(func(k: String, _d: Dictionary) -> void:
		if k == "aircraft":
			seen.append(k))
	_run(w, 240.0)
	runner.check(not w.planes.is_empty() or not seen.is_empty(), "planes went up")
	runner.check(not seen.is_empty(), "and one spotted the surfaced boat")
	return true


func test_planes_dont_see_a_deep_boat() -> bool:
	var w := _world() # at 45 m
	w.add_ship(Formations.ship_class("carrier"), Vector2(0, 3000), 90.0, 0.0).passive = true
	var seen := []
	w.event.connect(func(k: String, _d: Dictionary) -> void:
		if k == "aircraft":
			seen.append(k))
	_run(w, 300.0)
	runner.check(seen.is_empty(), "45 m down is invisible from the air")
	return true


func test_sandbox_keeps_ships_coming_and_turns_night() -> bool:
	var w := _world()
	var s := Sandbox.new()
	var nights := 0
	var was_night := false
	for i in int(1200.0 / 0.5):
		w.step(0.5)
		s.tick(w, 0.5)
		if w.conditions.night and not was_night:
			nights += 1
		was_night = w.conditions.night
	runner.check(w.ships.size() >= 3, "groups in the area after 20 min: %d ships" % w.ships.size())
	runner.check(nights == 1, "night fell once in 20 min")
	for ship in w.ships:
		runner.check(ship.pos.distance_to(w.sub.pos) < Sandbox.FORGET + 2000.0, "%s within reach" % ship.data.key)
	return true


func test_profile_ranks_and_hats() -> bool:
	var p := Profile.new()
	runner.check(p.rank() == 0 and p.unlocked("dixie") and not p.unlocked("officer"), "a new sailor is a seaman in a Dixie cup")
	p.merit = 0
	p.tons = 0
	var r := Profile.rank_for(15000)
	runner.check(Profile.RANKS[r][0] == "Petty Officer", "15,000 merit makes petty officer")
	runner.check(Profile.rank_for(10000 + 5000) == r, "a patrol home counts 5,000")
	return true


func test_voice_encoding_round_trips() -> bool:
	var s := PackedFloat32Array([0.0, 0.5, -0.5, 1.0, -1.0, 0.123])
	var back := Voice.decode(Voice.encode(s))
	var worst := 0.0
	for i in s.size():
		worst = maxf(worst, absf(back[i] - s[i]))
	runner.check(back.size() == s.size() and worst < 0.001, "16-bit voice round trip (worst %.5f)" % worst)
	return true
