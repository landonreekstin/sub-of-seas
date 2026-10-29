class_name OceanWorld
extends RefCounted
## The whole ocean simulation, with no rendering: the sub, AI ships and torpedoes.
## The host steps it authoritatively; clients step it between snapshots for smoothness.

## kind: "fired" | "hit" | "dud" | "sunk" | "ping" | "splash" | "blast" | "leak" | "power" | "breakdown" | "lost".
## Only emitted by authoritative steps.
signal event(kind: String, data: Dictionary)

const SHIP_DIR := "res://data/ships/%s.tres"
const BATTERY_WARNINGS := [0.2, 0.1] ## announce when the charge falls past these
const BREAKDOWN_TEXT := {
	"engine": "The diesels are knocking: the engine controls are down. Wrench, engine room!",
	"periscope": "The periscope's jammed: it shook loose running fast with it up.",
	"helm": "The steering's jammed hard over at flank! Wrench to the helm!",
	"sonar": "The sonar head's gone quiet after that ping. It needs a wrench.",
}

var time := 0.0
var sub: SubState
var ships: Array[ShipState] = []
var torpedoes: Array[Torpedo] = []
var charges: Array[DepthCharge] = []
var hull := HullState.new()
var air := AirState.new()
var crew_count := 1 ## players aboard, set by the host; they breathe
var lost := "" ## why the boat was lost, once it is
var dud_chance := 0.05
var rng := RandomNumberGenerator.new()
var _next_id := 1
var _battery_was := 1.0


func _init(sub_class: SubClassData, seed_value := 0) -> void:
	sub = SubState.new(sub_class)
	rng.seed = seed_value
	air.canisters = sub_class.co2_canisters


func add_ship(ship_class: ShipClassData, pos: Vector2, course: float, speed_kn: float) -> ShipState:
	var ship := ShipState.new(ship_class)
	ship.id = _take_id()
	ship.pos = pos
	ship.heading = course
	ship.course = course
	ship.base_course = course
	ship.speed = speed_kn * SubState.KNOT
	ship.ordered_speed = ship.speed
	ships.append(ship)
	if ship_class.asw:
		ShipAI.new(ship)
	return ship


## Escort `ship` keeps station at (right, ahead) metres from `guard`.
func set_escort(ship: ShipState, guard: ShipState, offset: Vector2) -> void:
	ship.ai.guard = guard
	ship.ai.guard_offset = offset


func drop_charge(pos: Vector2, set_depth: float) -> void:
	var dc := DepthCharge.new()
	dc.pos = pos
	dc.set_depth = clampf(set_depth, 10.0, 160.0)
	charges.append(dc)


## Our own active sonar: ranges and bearings to everything within 6 km, and every
## escort within 8 km now knows roughly where we are.
func own_ping() -> void:
	var echoes := []
	for ship in ships:
		var d := ship.pos.distance_to(sub.pos)
		if ship.is_sinking() or d > 6000.0:
			continue
		echoes.append({"b": ShipState.bearing(sub.pos, ship.pos), "r": d * rng.randf_range(0.97, 1.03)})
		if ship.ai != null and d < 8000.0:
			ship.ai.report(sub.pos, 300.0, rng, 0.7)
	event.emit("own_ping", {"echoes": echoes})
	if hull.station_comp.has("sonar") and rng.randf() < 0.04:
		breakdown("sonar")


## Every ship hears about the sub: convoys scatter, escorts come hunting.
func raise_alarm(pos: Vector2, error: float, awareness := 0.6) -> void:
	for ship in ships:
		if ship.is_sinking():
			continue
		if ship.ai != null:
			ship.ai.report(pos, error, rng, awareness)
		else:
			ship.alert()


func find_ship(id: int) -> ShipState:
	for ship in ships:
		if ship.id == id:
			return ship
	return null


## Fires from the bow (or stern) on the sub's heading plus the gyro angle.
func fire_torpedo(gyro: float, stern := false) -> Torpedo:
	var t := Torpedo.new()
	t.id = _take_id()
	var aim := sub.heading + (180.0 if stern else 0.0)
	var out := sub.direction() * sub.data.length * 0.5 * (-1.0 if stern else 1.0)
	t.pos = sub.pos + out
	t.heading = fposmod(aim + gyro, 360.0)
	t.dud = rng.randf() < dud_chance
	torpedoes.append(t)
	event.emit("fired", {"id": t.id})
	# Lookouts may spot the wake and trace it back.
	for ship in ships:
		if ship.ai != null and ship.pos.distance_to(sub.pos) < ship.data.lookout_range:
			ship.ai.report(sub.pos, 350.0, rng, 0.5)
	return t


func step(dt: float, authoritative := true) -> void:
	time += dt
	sub.step(dt)
	for ship in ships:
		if authoritative:
			_think(ship, dt)
		ship.step(dt, rng if authoritative else null)
	for t in torpedoes:
		t.step(dt)
		if authoritative and t.alive:
			_check_hits(t)
	torpedoes = torpedoes.filter(func(t: Torpedo) -> bool: return t.alive)
	if authoritative:
		ships = ships.filter(func(s: ShipState) -> bool: return s.sink < 1.0)
		_step_charges(dt)
		hull.step(dt, rng)
		if air.smoke.size() != hull.comps.size():
			air.smoke.resize(hull.comps.size())
		air.step(dt, sub.is_surfaced(), crew_count, hull)
		_hull_stress(dt)
		_power_checks()
		_wear(dt)
		sub.heaviness = hull.water_fraction()
		_check_lost()
	else:
		for dc in charges:
			dc.step(dt)


func _think(ship: ShipState, dt: float) -> void:
	if ship.is_sinking() or ship.passive:
		return
	if ship.ai != null:
		ship.ai.step(dt, self, rng)
		return
	# Unarmed ships: lookouts only. Seeing a periscope means a radio call.
	var gain := Detection.awareness_gain(ship, sub)
	ship.awareness = clampf(ship.awareness + (gain - ShipAI.DECAY) * dt, 0.0, 1.0)
	if ship.awareness > 0.6 and not ship.alerted:
		ship.alert()
		raise_alarm(sub.pos, ship.pos.distance_to(sub.pos) * 0.15)
		event.emit("spotted", {"ship": ship.id, "name": ship.data.display_name})


func _step_charges(dt: float) -> void:
	var left: Array[DepthCharge] = []
	for dc in charges:
		if not dc.step(dt):
			left.append(dc)
			continue
		# Distance to the nearest point of the hull (bow to stern segment), in 3D.
		var flat := dc.pos - sub.pos
		var half := sub.direction() * sub.data.length * 0.5
		var near := Geometry2D.get_closest_point_to_segment(dc.pos, sub.pos - half, sub.pos + half)
		var dist := Vector3(dc.pos.x - near.x, dc.depth - sub.depth, dc.pos.y - near.y).length()
		var info := {"x": dc.pos.x, "y": dc.pos.y, "d": dc.depth, "dist": dist, "dmg": []}
		if dist < DepthCharge.SHAKE and lost == "":
			# Where along the hull it went off: +0.5 bow .. -0.5 stern, mapped onto the interior.
			var along := clampf(flat.dot(sub.direction()) / sub.data.length, -0.5, 0.5)
			var side := signf(flat.dot(Vector2(sub.direction().y, -sub.direction().x)))
			var z0: float = hull.comps[0].z0 if not hull.comps.is_empty() else 0.0
			var z1: float = hull.comps[-1].z1 if not hull.comps.is_empty() else 0.0
			if not hull.comps.is_empty():
				info.dmg = hull.apply_blast(dist, lerpf(z1, z0, along + 0.5), side if side != 0.0 else 1.0, rng)
		event.emit("blast", info)
	charges = left


## Engine station "engine" runs the diesels: broken gear stops them, and diving with them
## running sends seawater down the main induction.
func set_diesel(i: int, on: bool) -> void:
	if i < 0 or i >= sub.diesels.size() or hull.is_broken("engine"):
		return
	if not on:
		sub.diesels[i] = 0.0
	elif sub.diesels[i] == 0.0 and sub.depth <= SubState.INDUCTION_DEPTH:
		sub.diesels[i] = 0.01 # starts cranking


func _power_checks() -> void:
	var on := sub.diesels.any(func(d: float) -> bool: return d > 0.0)
	if on and hull.is_broken("engine"):
		sub.diesels.fill(0.0)
		event.emit("power", {"text": "The diesels have stopped: the engine controls are wrecked."})
	elif on and sub.depth > SubState.INDUCTION_DEPTH and lost == "":
		sub.diesels.fill(0.0)
		var text := "Seawater down the induction! Diesels flooded. Stop the diesels BEFORE diving."
		var c: int = hull.station_comp.get("engine", -1)
		if c >= 0:
			hull.break_station("engine", true)
			hull.add_leak(c, 0, rng)
		event.emit("power", {"text": text})
	for w: float in BATTERY_WARNINGS:
		if _battery_was > w and sub.battery <= w:
			event.emit("power", {"text": "Battery at %d%%. Surface and run the diesels to charge." % roundi(w * 100.0)})
	if _battery_was > 0.0 and sub.battery <= 0.0:
		event.emit("power", {"text": "Battery flat! The motors have stopped. Surface (dive station, 1) and start the diesels."})
	_battery_was = sub.battery


## Gear driven hard wears out: chance per second of a breakdown (wrench work, no parts).
func _wear(dt: float) -> void:
	if lost != "":
		return
	var risks := {
		"engine": sub.diesels_running() / (25.0 * 60.0),
		"periscope": (1.0 / 180.0) if sub.periscope_raised and not sub.is_surfaced() and absf(sub.speed) > 5.0 * SubState.KNOT else 0.0,
		"helm": (1.0 / 600.0) if absi(sub.rudder) == 3 and sub.telegraph == 4 else 0.0,
	}
	for sid: String in risks:
		if hull.station_comp.has(sid) and not hull.is_broken(sid) and rng.randf() < risks[sid] * dt:
			breakdown(sid)


func breakdown(sid: String) -> void:
	hull.break_station(sid)
	event.emit("breakdown", {"station": sid, "text": BREAKDOWN_TEXT.get(sid, "")})


## Below test depth the hull starts to give.
func _hull_stress(dt: float) -> void:
	var over := (sub.depth - sub.data.test_depth) / float(sub.data.crush_depth - sub.data.test_depth)
	if over <= 0.0 or hull.comps.is_empty() or lost != "":
		return
	if rng.randf() < 0.05 * over * dt:
		var c := rng.randi() % hull.comps.size()
		hull.add_leak(c, 0, rng)
		event.emit("leak", {"text": "Rivets popping in the %s!" % hull.comps[c].name})


func _check_lost() -> void:
	if lost != "":
		return
	if sub.depth >= sub.data.crush_depth:
		lost = "Hull crushed at %d m." % roundi(sub.depth)
	elif sub.heaviness >= 0.65:
		lost = "Flooded. She went down with %d%% of the hull full of seawater." % roundi(sub.heaviness * 100.0)
	elif air.is_lethal():
		lost = "The air gave out. CO2 %.1f%%, oxygen %.1f%%: nobody was awake to bring her up." % [air.co2, air.o2]
	if lost != "":
		event.emit("lost", {"reason": lost})


func _check_hits(t: Torpedo) -> void:
	for ship in ships:
		if ship.is_sinking() or ship.distance_to_hull(t.pos) > ship.data.beam * 0.5 + 1.0:
			continue
		t.alive = false
		ship.alert()
		var info := {"ship": ship.id, "x": t.pos.x, "y": t.pos.y, "name": ship.data.display_name}
		if t.dud:
			event.emit("dud", info)
			return
		ship.hp -= 1.0
		event.emit("hit", info)
		if ship.is_sinking():
			info["tons"] = ship.data.tonnage
			event.emit("sunk", info)
		return


func to_snapshot() -> Dictionary:
	return {
		"t": time,
		"sub": sub.to_snapshot(),
		"ships": ships.map(func(s: ShipState) -> Dictionary: return s.to_snapshot()),
		"torps": torpedoes.map(func(t: Torpedo) -> Dictionary: return t.to_snapshot()),
		"dcs": charges.map(func(dc: DepthCharge) -> Array: return dc.to_snapshot()),
		"hull": hull.to_snapshot(),
		"air": air.to_snapshot(),
		"lost": lost,
	}


func apply_snapshot(s: Dictionary) -> void:
	time = s.t
	sub.apply_snapshot(s.sub)
	var kept: Array[ShipState] = []
	for ss: Dictionary in s.ships:
		var ship := find_ship(ss.id)
		if ship == null:
			ship = ShipState.new(load(SHIP_DIR % ss.k))
			ship.id = ss.id
		ship.apply_snapshot(ss)
		kept.append(ship)
	ships = kept
	var by_id := {}
	for t in torpedoes:
		by_id[t.id] = t
	var torps: Array[Torpedo] = []
	for ts: Dictionary in s.torps:
		var t: Torpedo = by_id.get(ts.id, Torpedo.new())
		t.id = ts.id
		t.pos = ts.p
		t.heading = ts.h
		torps.append(t)
	torpedoes = torps
	var dcs: Array[DepthCharge] = []
	for a: Array in s.dcs:
		var dc := DepthCharge.new()
		dc.pos = a[0]
		dc.depth = a[1]
		dc.set_depth = INF # clients never detonate
		dcs.append(dc)
	charges = dcs
	hull.apply_snapshot(s.hull)
	air.apply_snapshot(s.air)
	lost = s.lost


func _take_id() -> int:
	_next_id += 1
	return _next_id - 1
