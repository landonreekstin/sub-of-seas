extends RefCounted
## Ocean simulation tests. Each test returns true when it ran to the end.

const GATO := preload("res://data/subs/gato.tres")
const FREIGHTER := preload("res://data/ships/freighter.tres")

var runner: Object


func _world() -> OceanWorld:
	var w := OceanWorld.new(GATO, 1)
	w.dud_chance = 0.0
	return w


func _run(w: OceanWorld, seconds: float, dt := 0.05) -> void:
	for i in int(seconds / dt):
		w.step(dt)


func test_sub_reaches_ordered_speed() -> bool:
	var w := _world()
	w.sub.telegraph = 4
	_run(w, 120.0)
	var expected := GATO.surface_speed_kn * SubState.KNOT
	runner.check(absf(w.sub.speed - expected) < 0.05, "surfaced flank speed %.2f ~ %.2f" % [w.sub.speed, expected])
	runner.check(w.sub.pos.y > 500.0 and absf(w.sub.pos.x) < 1.0, "sub moved north")
	return true


func test_right_rudder_turns_clockwise() -> bool:
	var w := _world()
	w.sub.telegraph = 2
	w.sub.rudder = 3
	_run(w, 40.0)
	runner.check(w.sub.heading > 10.0 and w.sub.heading < 180.0, "heading went east: %.1f" % w.sub.heading)
	return true


func test_no_turning_when_stopped() -> bool:
	var w := _world()
	w.sub.rudder = 3
	_run(w, 20.0)
	runner.check(is_equal_approx(w.sub.heading, 0.0), "dead in the water does not turn")
	return true


func test_dives_to_ordered_depth() -> bool:
	var w := _world()
	w.sub.telegraph = 2
	w.sub.ordered_depth = 18.0
	_run(w, 60.0)
	runner.check(is_equal_approx(w.sub.depth, 18.0), "reached periscope depth: %.1f" % w.sub.depth)
	runner.check(w.sub.max_speed() < GATO.surface_speed_kn * SubState.KNOT, "submerged speed is lower")
	return true


func test_scope_height() -> bool:
	var w := _world()
	runner.check(w.sub.scope_height() > 5.0, "surfaced: bridge view")
	w.sub.depth = 18.0
	runner.check(w.sub.scope_height() < 0.0, "lowered scope sees nothing")
	w.sub.periscope_raised = true
	runner.check(w.sub.scope_height() > 0.5, "raised at periscope depth")
	w.sub.depth = 30.0
	runner.check(w.sub.scope_height() < 0.0, "too deep")
	return true


func test_torpedo_hits_ship_ahead() -> bool:
	var w := _world()
	var ship := w.add_ship(FREIGHTER, Vector2(0, 1500), 90.0, 0.0)
	var events: Array[String] = []
	w.event.connect(func(kind: String, _d: Dictionary) -> void: events.append(kind))
	w.fire_torpedo(0.0)
	_run(w, 80.0)
	runner.check(events.has("fired") and events.has("hit"), "fired and hit: %s" % [events])
	runner.check(ship.hp < FREIGHTER.hp, "ship damaged")
	runner.check(w.torpedoes.is_empty(), "torpedo consumed")
	runner.check(ship.alerted, "hit ship is alerted")
	return true


func test_gyro_angle_steers_torpedo() -> bool:
	var w := _world()
	w.add_ship(FREIGHTER, Vector2(0, 1500), 90.0, 0.0)
	var events: Array[String] = []
	w.event.connect(func(kind: String, _d: Dictionary) -> void: events.append(kind))
	w.fire_torpedo(45.0)
	_run(w, 200.0)
	runner.check(not events.has("hit"), "45 degree gyro misses a ship dead ahead")
	runner.check(w.torpedoes.is_empty(), "torpedo ran out of range")
	return true


func test_two_hits_sink_a_freighter() -> bool:
	var w := _world()
	var ship := w.add_ship(FREIGHTER, Vector2(0, 1000), 90.0, 0.0)
	var sunk := []
	w.event.connect(func(kind: String, d: Dictionary) -> void:
		if kind == "sunk":
			sunk.append(d))
	# A spread of two: after the first hit the ship is alerted and runs.
	w.fire_torpedo(0.0)
	w.fire_torpedo(1.0)
	_run(w, 60.0)
	runner.check(sunk.size() == 1 and sunk[0].tons == FREIGHTER.tonnage, "sunk once with tonnage")
	runner.check(ship.is_sinking(), "ship is sinking")
	_run(w, FREIGHTER.sink_time + 1.0)
	runner.check(w.ships.is_empty(), "wreck removed after sink time")
	return true


func test_snapshot_round_trip() -> bool:
	var host := _world()
	host.add_ship(FREIGHTER, Vector2(200, 3000), 270.0, 8.0)
	host.sub.telegraph = 2
	host.sub.ordered_depth = 18.0
	host.fire_torpedo(5.0)
	_run(host, 10.0)
	var client := OceanWorld.new(GATO)
	client.apply_snapshot(host.to_snapshot())
	runner.check(client.ships.size() == 1 and client.ships[0].data.key == "freighter", "ship created from snapshot")
	runner.check(client.sub.pos.is_equal_approx(host.sub.pos) and client.sub.telegraph == 2, "sub state copied")
	runner.check(client.torpedoes.size() == 1, "torpedo copied")
	client.step(0.1, false)
	runner.check(client.ships.size() == 1, "client step keeps ships")
	return true
