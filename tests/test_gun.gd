extends RefCounted
## The deck gun (M12): where rounds fall, what they hit, the noise it makes, and that every boat
## has the gun and its ammunition scuttle.

const GATO := preload("res://data/subs/gato.tres")
const FREIGHTER := preload("res://data/ships/freighter.tres")
const DESTROYER := preload("res://data/ships/destroyer.tres")

var runner: Object


func _world() -> OceanWorld:
	var w := OceanWorld.new(GATO, 11)
	w.sub.depth = 0.0
	return w


func test_fall_of_shot() -> bool:
	var w := _world()
	var f := w.add_ship(FREIGHTER, Vector2(0, 2000), 90.0, 0.0) # beam on, due north
	var from := Vector2.ZERO
	runner.check(OceanWorld.shell_strike(from, Vector2(0, 2000), 2000.0, f) != Vector2.INF, "a round on her hits")
	runner.check(OceanWorld.shell_strike(from, Vector2(0, 1950), 1950.0, f) == Vector2.INF, "one 50 m short splashes")
	runner.check(OceanWorld.shell_strike(from, Vector2(0, 2080), 2080.0, f) != Vector2.INF, "one 80 m over still hits her side on the way down")
	runner.check(OceanWorld.shell_strike(from, Vector2(0, 2600), 2600.0, f) == Vector2.INF, "one well over misses")
	runner.check(OceanWorld.shell_strike(from, Vector2(60, 2000), 2000.0, f) != Vector2.INF, "along her length is fine")
	runner.check(OceanWorld.shell_strike(from, Vector2(120, 2000), 2000.0, f) == Vector2.INF, "past her bow is a miss")
	runner.check(OceanWorld.shell_descent(1000.0) < OceanWorld.shell_descent(5000.0), "rounds fall steeper further out")
	return true


func test_rounds_fly_hit_and_sink() -> bool:
	var w := _world()
	var f := w.add_ship(FREIGHTER, Vector2(0, 1500), 90.0, 0.0)
	f.ordered_speed = 0.0
	var seen := []
	w.event.connect(func(k: String, _d: Dictionary) -> void: seen.append(k))
	var hits := 0
	for n in 30:
		w.fire_gun(0.0, f.pos.distance_to(w.sub.pos), 0.18)
		var before := f.hp
		for i in 35:
			w.step(0.1)
		f.speed = 0.0
		f.ordered_speed = 0.0
		if f.hp < before:
			hits += 1
		if f.is_sinking():
			break
	runner.check(seen.has("gun"), "the gun's report is an event")
	runner.check(seen.has("gun_hit") and hits > 3, "most rounds laid on her hit (%d)" % hits)
	runner.check(f.is_sinking() and seen.has("sunk"), "enough of them sink a freighter")
	runner.check(w.shells.is_empty(), "nothing left in the air")
	return true


func test_the_gun_gives_her_away() -> bool:
	var w := _world()
	var near := w.add_ship(FREIGHTER, Vector2(0, 8000), 90.0, 8.0)
	var dd := w.add_ship(DESTROYER, Vector2(9000, 0), 0.0, 14.0)
	var far := w.add_ship(FREIGHTER, Vector2(0, -20000), 90.0, 8.0)
	w.fire_gun(0.0, 3000.0, 0.18)
	runner.check(near.alerted, "a merchant 8 km off hears it and runs")
	runner.check(dd.ai.mode >= ShipAI.Mode.SEARCH, "an escort 9 km off comes looking")
	runner.check(not far.alerted, "20 km off nobody hears it")
	return true


func test_every_boat_has_a_gun_and_a_scuttle() -> bool:
	for key in ["s_boat", "gato", "narwhal"]:
		var data: SubClassData = load("res://data/subs/%s.tres" % key)
		var interior := SubInterior.create(data)
		interior.build()
		runner.check(interior.stations.has("gun") and interior.stations.has("ammo"), "%s: gun and ammunition scuttle" % key)
		runner.check(interior.stations.ammo.has_meta("where"), "%s: the scuttle says where it is" % key)
		runner.check(data.gun_ready > 0 and data.gun_rounds > data.gun_ready and data.gun_damage > 0.0, "%s: gun data" % key)
		interior.free()
	return true
