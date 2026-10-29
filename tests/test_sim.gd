extends RefCounted
## Ocean simulation tests. Each test returns true when it ran to the end.

const GATO := preload("res://data/subs/gato.tres")
const FREIGHTER := preload("res://data/ships/freighter.tres")

var runner: Object


func _world() -> OceanWorld:
	var w := OceanWorld.new(GATO, 1)
	w.dud_chance = 0.0
	return w


## At periscope depth with the scope down, so lookouts don't see her and run.
func _submerged_world() -> OceanWorld:
	var w := _world()
	w.sub.depth = GATO.periscope_depth
	w.sub.ordered_depth = GATO.periscope_depth
	w.sub.ballast = 1.0
	return w


func _run(w: OceanWorld, seconds: float, dt := 0.05) -> void:
	for i in int(seconds / dt):
		w.step(dt)


func test_sub_reaches_ordered_speed() -> bool:
	var w := _world()
	w.sub.diesels.assign([1.0, 1.0])
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
	_run(w, 20.0)
	runner.check(w.sub.depth < 0.5, "planes alone can't take her under with the tanks dry: %.1f" % w.sub.depth)
	w.sub.ballast_order("vent")
	_run(w, 70.0)
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
	var w := _submerged_world()
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
	var w := _submerged_world()
	w.add_ship(FREIGHTER, Vector2(0, 1500), 90.0, 0.0)
	var events: Array[String] = []
	w.event.connect(func(kind: String, _d: Dictionary) -> void: events.append(kind))
	w.fire_torpedo(45.0)
	_run(w, 200.0)
	runner.check(not events.has("hit"), "45 degree gyro misses a ship dead ahead")
	runner.check(w.torpedoes.is_empty(), "torpedo ran out of range")
	return true


func test_two_hits_sink_a_freighter() -> bool:
	var w := _submerged_world()
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
	host.sub.ballast_order("vent")
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


# --- Battery and diesels ------------------------------------------------------

func test_flank_drains_battery_much_faster_than_slow() -> bool:
	var slow := _submerged_world()
	slow.sub.telegraph = 1
	var flank := _submerged_world()
	flank.sub.telegraph = 4
	_run(slow, 60.0)
	_run(flank, 60.0)
	var slow_used := 1.0 - slow.sub.battery
	var flank_used := 1.0 - flank.sub.battery
	runner.check(slow_used > 0.0 and flank_used > slow_used * 4.0, "flank used %.4f vs slow %.4f" % [flank_used, slow_used])
	var minutes := 1.0 / slow.sub.battery_drain(GATO.submerged_speed_kn * SubState.KNOT * 0.25) / 60.0
	runner.check(absf(minutes - GATO.battery_endurance_min) < 0.5, "AHEAD 1/3 lasts the class endurance: %.1f min" % minutes)
	return true


func test_flat_battery_stops_the_motors() -> bool:
	var w := _submerged_world()
	w.sub.battery = 0.001
	w.sub.telegraph = 3
	_run(w, 90.0)
	runner.check(w.sub.battery == 0.0, "battery flat")
	runner.check(absf(w.sub.speed) < 0.01, "no way on: %.2f m/s" % w.sub.speed)
	return true


func test_diesels_charge_on_the_surface() -> bool:
	var w := _world()
	w.sub.battery = 0.5
	w.set_diesel(0, true)
	w.set_diesel(1, true)
	_run(w, 10.0)
	runner.check(w.sub.diesels_running() == 2, "both diesels running after cranking")
	var before := w.sub.battery
	_run(w, 60.0)
	runner.check(w.sub.battery > before + 0.05, "charging stopped: %.3f -> %.3f" % [before, w.sub.battery])
	# Full speed takes most of their power.
	w.sub.telegraph = 4
	_run(w, 120.0)
	runner.check(w.sub.charge_rate > 0.0 and w.sub.charge_rate < 0.3 / (GATO.charge_minutes * 60.0), "charges slowly at flank: %f" % w.sub.charge_rate)
	return true


func test_one_diesel_is_slower_on_the_surface() -> bool:
	var w := _world()
	w.sub.diesels.assign([1.0, 0.0])
	runner.check(is_equal_approx(w.sub.max_speed(), GATO.surface_speed_kn * SubState.KNOT * 0.7), "one diesel: 70%% speed")
	w.sub.diesels.assign([0.0, 0.0])
	runner.check(is_equal_approx(w.sub.max_speed(), GATO.submerged_speed_kn * SubState.KNOT), "no diesels: battery speed")
	return true


func test_diesels_wont_start_submerged() -> bool:
	var w := _submerged_world()
	w.set_diesel(0, true)
	runner.check(w.sub.diesels[0] == 0.0, "no air, no start")
	return true


func test_diving_with_diesels_floods_them() -> bool:
	var w := _world()
	w.hull.setup([{"name": "a", "z0": -10.0, "z1": 0.0}, {"name": "engine room", "z0": 0.0, "z1": 10.0}], {}, {"engine": 1})
	w.sub.diesels.assign([1.0, 1.0])
	var said := []
	w.event.connect(func(kind: String, data: Dictionary) -> void:
		if kind == "power":
			said.append(data.text))
	w.sub.telegraph = 2
	w.sub.ordered_depth = 18.0
	w.sub.ballast_order("vent")
	_run(w, 40.0)
	runner.check(w.sub.diesels_running() == 0, "diesels stopped")
	runner.check(w.hull.is_broken("engine"), "engine controls broken")
	runner.check(w.hull.leaks.size() == 1 and w.hull.leaks[0].c == 1, "leak in the engine room")
	runner.check(said.size() == 1, "one announcement: %s" % [said])
	w.set_diesel(0, true)
	runner.check(w.sub.diesels[0] == 0.0, "broken controls start nothing")
	return true


func test_battery_warnings() -> bool:
	var w := _submerged_world()
	w.sub.battery = 0.205
	w.sub.telegraph = 1
	var said := []
	w.event.connect(func(kind: String, data: Dictionary) -> void:
		if kind == "power":
			said.append(data.text))
	_run(w, 60.0)
	runner.check(said.size() == 1 and "20%" in said[0], "warned once at 20%%: %s" % [said])
	return true


func test_power_snapshot_roundtrip() -> bool:
	var a := _world()
	a.sub.battery = 0.42
	a.sub.diesels.assign([1.0, 0.3])
	var b := _world()
	b.apply_snapshot(a.to_snapshot())
	runner.check(is_equal_approx(b.sub.battery, 0.42) and b.sub.diesels == a.sub.diesels, "battery and diesels replicate")
	return true


# --- Ballast ------------------------------------------------------------------

func test_blowing_ballast_surfaces_her() -> bool:
	var w := _submerged_world()
	w.sub.ordered_depth = 0.0
	_run(w, 60.0)
	runner.check(absf(w.sub.depth - SubState.AWASH_DEPTH) < 0.2, "planes only bring her to awash: %.1f" % w.sub.depth)
	w.sub.ballast_order("blow")
	_run(w, 30.0)
	runner.check(w.sub.is_surfaced() and w.sub.ballast == 0.0, "blown dry and surfaced: %.1f m" % w.sub.depth)
	runner.check(absf(w.sub.hp_air - (1.0 - SubState.BLOW_AIR)) < 0.01, "a normal blow costs its air: %.3f" % w.sub.hp_air)
	return true


func test_emergency_blow_saves_a_flooding_boat() -> bool:
	var w := _submerged_world()
	w.hull.setup([{"name": "a", "z0": -10.0, "z1": 0.0}, {"name": "b", "z0": 0.0, "z1": 10.0}], {})
	w.hull.comps[0].water = 0.7
	w.sub.telegraph = 1
	_run(w, 10.0)
	runner.check(w.sub.depth > GATO.periscope_depth + 1.0, "heavy boat sinking: %.1f" % w.sub.depth)
	w.sub.ballast_order("emergency")
	_run(w, 60.0)
	runner.check(w.sub.is_surfaced(), "emergency blow brought her up: %.1f" % w.sub.depth)
	runner.check(w.sub.hp_air < 0.7, "and used plenty of air: %.2f" % w.sub.hp_air)
	return true


func test_no_air_no_blow() -> bool:
	var w := _submerged_world()
	w.sub.hp_air = 0.0
	w.sub.ballast_order("blow")
	_run(w, 10.0)
	runner.check(w.sub.ballast == 1.0, "tanks stay flooded with empty air banks")
	return true


func test_compressors_refill_air_on_diesels() -> bool:
	var w := _world()
	w.sub.hp_air = 0.5
	w.sub.diesels.assign([1.0, 0.0])
	_run(w, 60.0)
	runner.check(w.sub.hp_air > 0.55, "air banks refilling: %.2f" % w.sub.hp_air)
	return true


# --- Air ----------------------------------------------------------------------

func test_co2_builds_submerged_and_clears_surfaced() -> bool:
	var w := _submerged_world()
	w.crew_count = 4
	_run(w, 600.0, 0.5)
	runner.check(w.air.co2 > 2.0 and w.air.o2 < 19.0, "10 min down with 4 crew: CO2 %.2f O2 %.2f" % [w.air.co2, w.air.o2])
	var fouled := w.air.co2
	var scrubbed := _submerged_world()
	scrubbed.crew_count = 4
	scrubbed.air.load_canister()
	_run(scrubbed, 300.0, 0.5)
	runner.check(scrubbed.air.co2 < 0.5 and scrubbed.air.canisters == GATO.co2_canisters - 1, "the scrubber keeps CO2 down: %.2f" % scrubbed.air.co2)
	w.sub.depth = 0.0
	w.sub.ballast = 0.0
	w.sub.ordered_depth = 0.0
	_run(w, 60.0, 0.5)
	runner.check(w.air.co2 < fouled * 0.1, "surfacing vents it: %.2f" % w.air.co2)
	return true


func test_bad_air_loses_the_boat() -> bool:
	var w := _submerged_world()
	w.air.co2 = AirState.CO2_LOST - 0.01
	w.crew_count = 4
	var reason := []
	w.event.connect(func(k: String, d: Dictionary) -> void:
		if k == "lost":
			reason.append(d.reason))
	_run(w, 10.0)
	runner.check(reason.size() == 1 and reason[0].begins_with("The air gave out"), "lost to the air: %s" % [reason])
	return true


func test_fire_smokes_its_room_and_spreads_through_open_doors() -> bool:
	var w := _submerged_world()
	w.hull.setup([{"name": "a", "z0": -10.0, "z1": 0.0}, {"name": "b", "z0": 0.0, "z1": 10.0}, {"name": "c", "z0": 10.0, "z1": 20.0}],
		{"ab": [0, 1], "bc": [1, 2]})
	w.hull.doors_open["bc"] = false
	w.hull.add_fire(0, w.rng)
	_run(w, 90.0)
	runner.check(w.air.smoke[0] > 0.45, "smoke in the burning room: %.2f" % w.air.smoke[0])
	runner.check(w.air.smoke[1] > 0.05, "through the open door: %.2f" % w.air.smoke[1])
	runner.check(w.air.smoke[2] == 0.0, "not past a shut door")
	runner.check(w.air.badness_in(0) > w.air.badness_in(2), "worse to breathe where it burns")
	return true
