extends RefCounted
## Destroyer AI, detection, depth charges and the hull damage model.

const GATO := preload("res://data/subs/gato.tres")
const DESTROYER := preload("res://data/ships/destroyer.tres")
const FREIGHTER := preload("res://data/ships/freighter.tres")
const COMPS := [
	{"name": "forward torpedo room", "z0": -22.0, "z1": -8.0},
	{"name": "control room", "z0": -8.0, "z1": 0.0},
	{"name": "engine room", "z0": 0.0, "z1": 14.0},
]
const LINKS := {"fwd": [0, 1], "aft": [1, 2]}

var runner: Object


func _world(seed_value := 3) -> OceanWorld:
	var w := OceanWorld.new(GATO, seed_value)
	w.hull.setup(COMPS, LINKS, {"helm": 1, "dive": 1, "tube_1": 0})
	w.sub.depth = 18.0
	w.sub.ballast = 1.0
	w.sub.ordered_depth = 18.0
	return w


func _run(w: OceanWorld, seconds: float, dt := 0.1) -> void:
	for i in int(seconds / dt):
		w.step(dt)


func test_detection_numbers() -> bool:
	var w := _world()
	var dd := w.add_ship(DESTROYER, Vector2(0, 2000), 90.0, 14.0)
	w.sub.telegraph = 1
	w.sub.speed = w.sub.max_speed() * 0.25
	var silent := Detection.awareness_gain(dd, w.sub)
	runner.check(silent < ShipAI.DECAY, "creeping, scope down at 2 km goes unheard (%.4f)" % silent)
	w.sub.periscope_raised = true
	dd.pos = Vector2(0, 1200)
	var scope := Detection.awareness_gain(dd, w.sub)
	runner.check(scope > ShipAI.DECAY * 2.0, "raised scope at 1.2 km gets noticed (%.4f)" % scope)
	w.sub.periscope_raised = false
	w.sub.speed = w.sub.max_speed()
	dd.pos = Vector2(0, 800)
	runner.check(Detection.awareness_gain(dd, w.sub) > silent * 5.0, "flank speed is much louder")
	dd.speed = 30.0 * SubState.KNOT
	runner.check(Detection.hearing_factor(dd) < 0.3, "a ship at 30 kn is deaf")
	w.sub.depth = 100.0
	w.sub.ballast = 1.0
	dd.pos = Vector2(0, 2600)
	runner.check(Detection.ping_chance(dd, w.sub) == 0.0, "out of sonar range")
	dd.pos = Vector2(0, 80)
	runner.check(Detection.ping_chance(dd, w.sub) == 0.0, "too close: under the beam")
	return true


func test_raised_scope_starts_a_search() -> bool:
	var w := _world()
	var dd := w.add_ship(DESTROYER, Vector2(900, 0), 0.0, 0.0)
	dd.ai.guard = w.add_ship(FREIGHTER, Vector2(900, 0), 0.0, 0.0) # keeps it loitering
	w.sub.periscope_raised = true
	_run(w, 120.0)
	runner.check(dd.ai.mode >= ShipAI.Mode.SEARCH, "destroyer is searching (mode %d, awareness %.2f)" % [dd.ai.mode, dd.awareness])
	return true


func test_hunt_ends_in_depth_charges() -> bool:
	var w := _world()
	w.sub.depth = 60.0
	w.sub.ballast = 1.0
	w.sub.ordered_depth = 60.0
	var dd := w.add_ship(DESTROYER, Vector2(0, 1600), 180.0, 14.0)
	var kinds := {}
	w.event.connect(func(k: String, _d: Dictionary) -> void: kinds[k] = kinds.get(k, 0) + 1)
	dd.ai.report(w.sub.pos, 0.0, w.rng, 0.9)
	_run(w, 240.0)
	runner.check(kinds.get("ping", 0) > 0, "it pinged")
	runner.check(kinds.get("splash", 0) > 0, "it made an attack run")
	runner.check(kinds.get("blast", 0) >= DESTROYER.dc_pattern, "a full pattern went off (%d)" % kinds.get("blast", 0))
	runner.check(dd.ai.dc_left < DESTROYER.depth_charges, "charges were used")
	return true


func test_hit_on_convoy_brings_escort() -> bool:
	var w := _world()
	var f := w.add_ship(FREIGHTER, Vector2(0, 1500), 270.0, 8.0)
	var dd := w.add_ship(DESTROYER, Vector2(-1000, 1500), 270.0, 8.0)
	w.set_escort(dd, f, Vector2(0, 1000))
	w.raise_alarm(w.sub.pos, 300.0)
	runner.check(f.alerted, "freighter alerted")
	runner.check(dd.ai.mode == ShipAI.Mode.SEARCH, "escort searching")
	return true


func test_escort_keeps_station() -> bool:
	var w := _world()
	var f := w.add_ship(FREIGHTER, Vector2(5000, 5000), 270.0, 8.0)
	var dd := w.add_ship(DESTROYER, Vector2(5000, 4000), 270.0, 8.0)
	w.set_escort(dd, f, Vector2(0, 1000))
	_run(w, 300.0)
	var spot := f.pos + f.direction() * 1000.0
	runner.check(dd.pos.distance_to(spot) < 400.0, "escort ahead of the freighter (%.0f m off)" % dd.pos.distance_to(spot))
	return true


func test_leak_floods_through_open_door() -> bool:
	var w := _world()
	var h := w.hull
	h.add_leak(0, 2, w.rng)
	for i in 600:
		h.step(0.1, w.rng)
	runner.check(h.comps[0].water > 0.0 and h.comps[1].water > 0.0, "water spread through the open door")
	h.doors_open["fwd"] = false
	var ctrl: float = h.comps[1].water
	for i in 300:
		h.step(0.1, w.rng)
	runner.check(is_equal_approx(h.comps[1].water, ctrl) or h.comps[1].water < ctrl, "closed door holds water back")
	runner.check(h.water_fraction() > 0.0, "hull water fraction")
	var leak_id := str(h.leaks[0].id)
	var done := false
	for i in 200:
		done = h.work("torch", leak_id, 0.1) or done
	runner.check(done and h.leaks.is_empty(), "welded shut")
	var before: float = h.comps[0].water
	h.pumps.append({"c": 0, "p": Vector3.ZERO})
	for i in 100:
		h.step(0.1, w.rng)
	runner.check(h.comps[0].water < before, "pump drains the room")
	return true


func test_fire_grows_and_is_put_out() -> bool:
	var w := _world()
	var h := w.hull
	var f := h.add_fire(2, w.rng)
	for i in 100:
		h.step(0.1, w.rng)
	runner.check(f.size > 0.25, "fire grew (%.2f)" % f.size)
	var done := false
	for i in 100:
		done = h.work("extinguisher", str(f.id), 0.1) or done
	runner.check(done and h.fires_in(2) == 0, "fire out")
	h.add_fire(2, w.rng)
	h.comps[2].water = 0.3
	h.step(0.1, w.rng)
	runner.check(h.fires_in(2) == 0, "flooding drowns a fire")
	return true


func test_close_blast_damages_the_right_room() -> bool:
	var w := _world()
	var msgs := []
	w.event.connect(func(k: String, d: Dictionary) -> void:
		if k == "blast":
			msgs.append_array(d.dmg))
	# Just off the bow (sub heads north), at the sub's depth.
	w.drop_charge(Vector2(3, GATO.length * 0.4), w.sub.depth)
	_run(w, 10.0)
	runner.check(not w.hull.leaks.is_empty(), "close blast holed the hull")
	runner.check(w.hull.leaks[0].c == 0, "the bow blast holed the torpedo room")
	runner.check(w.hull.leaks[0].p.x > 0.0, "starboard side")
	runner.check(msgs.size() > 0, "damage reported")
	return true


func test_flooded_boat_sinks_and_is_lost() -> bool:
	var w := _world()
	w.sub.telegraph = 1
	w.sub.ballast = 1.0 # dived: dry tanks would float even this much water
	w.hull.comps[0].water = 0.8
	w.hull.comps[1].water = 0.6
	w.hull.doors_open = {"fwd": false, "aft": false}
	var reason := []
	w.event.connect(func(k: String, d: Dictionary) -> void:
		if k == "lost":
			reason.append(d.reason))
	_run(w, 30.0)
	runner.check(w.sub.depth > 25.0, "heavy boat sinks below ordered depth (%.1f)" % w.sub.depth)
	_run(w, 900.0)
	runner.check(reason.size() == 1 and reason[0].begins_with("Hull crushed"), "lost: %s" % [reason])
	return true


func test_snapshot_carries_hunter_state() -> bool:
	var w := _world()
	var dd := w.add_ship(DESTROYER, Vector2(0, 1500), 180.0, 14.0)
	dd.ai.set_mode(ShipAI.Mode.HUNT)
	w.drop_charge(Vector2(10, 10), 50.0)
	w.hull.add_leak(1, 1, w.rng)
	w.hull.broken["helm"] = 3.0
	var c := _world()
	c.apply_snapshot(w.to_snapshot())
	runner.check(c.ships[0].mode == ShipAI.Mode.HUNT, "mode replicated")
	runner.check(c.charges.size() == 1, "charge replicated")
	runner.check(c.hull.leaks.size() == 1 and c.hull.is_broken("helm"), "hull replicated")
	return true


func test_wrecked_gear_needs_parts_before_the_wrench() -> bool:
	var h := HullState.new().setup([{"name": "a", "z0": 0.0, "z1": 10.0}], {}, {"helm": 0})
	h.break_station("helm", true)
	runner.check(not h.work("wrench", "helm", 10.0) and h.is_broken("helm"), "wrench does nothing to wrecked gear")
	runner.check(h.work("parts", "helm", HullState.PARTS_SECONDS), "parts fitted")
	runner.check(h.work("wrench", "helm", HullState.WRENCH_SECONDS) and not h.is_broken("helm"), "then the wrench fixes it")
	return true


func test_hard_driven_gear_wears_out() -> bool:
	var w := _world()
	w.hull.setup([{"name": "a", "z0": -10.0, "z1": 10.0}], {}, {"engine": 0, "helm": 0})
	w.sub.depth = 0.0 # surfaced, on the diesels
	w.sub.ordered_depth = 0.0
	w.sub.ballast = 0.0
	w.sub.diesels.assign([1.0, 1.0])
	w.sub.telegraph = 4
	w.sub.rudder = 3
	var said := []
	w.event.connect(func(k: String, d: Dictionary) -> void:
		if k == "breakdown":
			said.append(d.station))
	_run(w, 1800.0, 0.5)
	runner.check(said.has("engine") and said.has("helm"), "half an hour flat out broke something: %s" % [said])
	return true


## A torpedo track seen by a destroyer's lookouts sends her down it, toward where it was
## fired from; without the torpedo she never knows the boat is there.
func test_torpedo_track_gives_the_boat_away() -> bool:
	for fire in [false, true]:
		var w := _world(5)
		w.sub.depth = 60.0
		w.sub.ordered_depth = 60.0
		w.sub.telegraph = 0
		w.sub.speed = 0.0
		var dd := w.add_ship(DESTROYER, Vector2(300, 2600), 270.0, 6.0)
		if fire:
			w.fire_torpedo(0.0)
		_run(w, 60.0)
		if fire:
			runner.check(dd.ai.mode >= ShipAI.Mode.SEARCH, "the destroyer saw the track and came looking (mode %d)" % dd.ai.mode)
			runner.check(dd.ai.contact_pos.distance_to(w.sub.pos) < 800.0, "toward where it was fired from (%.0f m off)" % dd.ai.contact_pos.distance_to(w.sub.pos))
		else:
			runner.check(dd.ai.mode == ShipAI.Mode.PATROL, "with no torpedo she never knew (mode %d)" % dd.ai.mode)
	return true


## The fixed bilge pump drains the wettest compartment fast, off the battery, and is loud.
func test_bilge_pump() -> bool:
	var w := _world()
	w.hull.comps[0].water = 0.3
	w.hull.comps[2].water = 0.1
	var quiet := Detection.sub_noise(w.sub)
	var battery := w.sub.battery
	w.hull.bilge_on = true
	_run(w, 5.0)
	runner.check(w.hull.bilge_from == 0, "it draws from the wettest compartment")
	runner.check(w.hull.comps[0].water < 0.3 - 0.06, "and drains it fast (%.2f)" % w.hull.comps[0].water)
	runner.check(Detection.sub_noise(w.sub) > quiet + 0.2, "it's loud")
	runner.check(w.sub.battery < battery, "it runs off the battery")
	w.sub.battery = 0.0
	_run(w, 1.0)
	runner.check(not w.hull.bilge_on and w.hull.bilge_from < 0, "no power, no pump")
	return true
