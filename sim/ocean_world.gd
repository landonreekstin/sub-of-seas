class_name OceanWorld
extends RefCounted
## The whole ocean simulation, with no rendering: the sub, AI ships and torpedoes.
## The host steps it authoritatively; clients step it between snapshots for smoothness.

## kind: "fired" | "hit" | "dud" | "sunk" | "ping" | "splash" | "blast" | "leak" | "power" | "breakdown" |
## "aircraft" | "lost".
## Only emitted by authoritative steps.
signal event(kind: String, data: Dictionary)

const SHIP_DIR := "res://data/ships/%s.tres"
const TRACK_SIGHT := 1500.0 ## by day in a moderate sea, how far a lookout sees a torpedo track
const TRACK_SPOT_RATE := 0.6 ## per second, close by
const TRACK_MIN_RUN := 150.0 ## a fresh track is too short to follow back
const BILGE_DRAIN := 1.0 / 3600.0 ## battery per second the bilge pump takes (an hour flat out empties it)
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
var planes: Array[Aircraft] = []
var whales: Array[Whale] = []
var hull := HullState.new()
var air := AirState.new()
var conditions := Conditions.new()
var seabed := Seabed.new()
var _ground_cooldown := 0.0
var crew_count := 1 ## players aboard, set by the host; they breathe
var lost := "" ## why the boat was lost, once it is
var dud_chance := 0.05
var realism := "arcade" ## a Realism key, set by Realism.apply
var escort_sharpness := 1.0 ## the realism level: escorts pick the boat up this much faster
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


## A whale somewhere `dist` metres from the boat.
func add_whale(dist: float) -> Whale:
	var wh := Whale.new()
	wh.id = _take_id()
	wh.pos = sub.pos + Vector2.from_angle(rng.randf() * TAU) * dist
	wh.heading = rng.randf() * 360.0
	wh.depth = rng.randf_range(5.0, 35.0)
	whales.append(wh)
	return wh


## Escort `ship` keeps station at (right, ahead) metres from `guard`.
func set_escort(ship: ShipState, guard: ShipState, offset: Vector2) -> void:
	ship.ai.guard = guard
	ship.ai.guard_offset = offset


func drop_charge(pos: Vector2, set_depth: float, power := 1.0) -> void:
	var dc := DepthCharge.new()
	dc.pos = pos
	dc.set_depth = clampf(set_depth, 10.0, 160.0)
	dc.power = power
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
	for wh in whales: # a whale's back returns an echo just like a hull
		var d := wh.pos.distance_to(sub.pos)
		if d < 6000.0:
			echoes.append({"b": ShipState.bearing(sub.pos, wh.pos), "r": d * rng.randf_range(0.97, 1.03)})
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
	Detection.conditions = conditions
	Detection.sharpness = escort_sharpness
	var before := sub.pos
	sub.step(dt)
	_check_ground(before, dt, authoritative)
	for ship in ships:
		if authoritative:
			_think(ship, dt)
		ship.step(dt, rng if authoritative else null, seabed)
	for wh in whales:
		wh.step(dt, rng if authoritative else null)
	for t in torpedoes:
		t.step(dt)
		if authoritative and t.alive:
			_check_hits(t)
		if authoritative and t.alive and seabed.floor_depth(t.pos) < 2.0:
			t.alive = false
			event.emit("beached", {"x": t.pos.x, "y": t.pos.y})
	torpedoes = torpedoes.filter(func(t: Torpedo) -> bool: return t.alive)
	if authoritative:
		_spot_tracks(dt)
		ships = ships.filter(func(s: ShipState) -> bool: return s.sink < 1.0)
		_step_charges(dt)
		# The bilge pump runs off the battery, and it's loud.
		if hull.bilge_on and (sub.battery <= 0.0 or hull.is_broken("bilge")):
			hull.bilge_on = false
			event.emit("power", {"text": "The bilge pump has stopped." if sub.battery > 0.0 else "No power: the bilge pump has stopped."})
		hull.step(dt, rng)
		sub.bilge_running = hull.bilge_from >= 0
		if sub.bilge_running:
			sub.battery = maxf(0.0, sub.battery - BILGE_DRAIN * dt)
		if air.smoke.size() != hull.comps.size():
			air.smoke.resize(hull.comps.size())
		air.step(dt, sub.is_surfaced(), crew_count, hull)
		_hull_stress(dt)
		_power_checks()
		_wear(dt)
		_gunnery(dt)
		_air_patrols(dt)
		sub.heaviness = hull.water_fraction()
		_check_lost()
	else:
		for dc in charges:
			dc.step(dt)
		for p in planes:
			p.pos += p.direction() * Aircraft.SPEED * dt


## Striking bottom or running aground: she stops dead where the water got too shallow, sits on
## a bottom she dives onto, and a hard hit opens a leak in the bow.
func _check_ground(before: Vector2, dt: float, authoritative: bool) -> void:
	_ground_cooldown = maxf(0.0, _ground_cooldown - dt)
	var floor_at := seabed.floor_depth(sub.pos)
	var keel := maxf(sub.depth, SubState.AWASH_DEPTH)
	if floor_at >= keel:
		return
	var impact := absf(sub.speed)
	if floor_at < SubState.AWASH_DEPTH or seabed.floor_depth(before) >= keel:
		sub.pos = before # the ground rises ahead of her: no further that way
		sub.speed = 0.0
	else:
		impact *= 0.3 # settling onto the bottom she dived to
	sub.depth = minf(sub.depth, maxf(floor_at - 0.2, 0.0))
	if not authoritative or _ground_cooldown > 0.0:
		return
	_ground_cooldown = 8.0
	if impact > 1.0 and not hull.comps.is_empty():
		hull.add_leak(0, 1 if impact > 2.5 else 0, rng)
		event.emit("grounded", {"text": "We've struck bottom! Leak in the %s!" % hull.comps[0].name, "hard": true})
	else:
		event.emit("grounded", {"text": "Touched bottom at %d m." % roundi(floor_at), "hard": false})


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


## Warship lookouts who see a torpedo's bubble track know where it came from (design: "the
## wake can give the sub away") and come down it. Merchants don't react to a track: dodging
## the very torpedo they saw would be too harsh for the arcade game.
func _spot_tracks(dt: float) -> void:
	for t in torpedoes:
		if t.spotted or t.run < TRACK_MIN_RUN:
			continue
		for ship in ships:
			if ship.ai == null or ship.is_sinking() or ship.passive:
				continue
			var d := ship.pos.distance_to(t.pos)
			var sight := TRACK_SIGHT * conditions.visual_factor()
			if d > sight or rng.randf() > TRACK_SPOT_RATE * (1.0 - d / sight) * Detection.sharpness * dt:
				continue
			t.spotted = true
			ship.ai.report(t.origin(), 250.0, rng, 0.85)
			event.emit("track_spotted", {"ship": ship.id, "name": ship.data.display_name})
			break


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
		# A small charge does at 10 m what a big one does at 10 / power.
		var dist := Vector3(dc.pos.x - near.x, dc.depth - sub.depth, dc.pos.y - near.y).length() / dc.power
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


## Carriers and cruisers keep their planes up; each plane flies its own patrol.
func _air_patrols(dt: float) -> void:
	for ship in ships:
		if ship.data.aircraft <= 0 or ship.is_sinking():
			continue
		var up := planes.filter(func(p: Aircraft) -> bool: return p.home == ship).size()
		ship.launch_timer -= dt
		if up < ship.data.aircraft and ship.launch_timer <= 0.0:
			ship.launch_timer = 60.0
			var p := Aircraft.new()
			p.id = _take_id()
			p.home = ship
			p.pos = ship.pos
			p.heading = rng.randf() * 360.0
			p.altitude = 30.0
			planes.append(p)
	planes = planes.filter(func(p: Aircraft) -> bool: return p.step(dt, self, rng))


## Surfaced near anything with guns that knows she's there, she gets shelled. A hit does
## what a depth charge `gun_blast` metres away would.
func _gunnery(dt: float) -> void:
	if not sub.is_surfaced() or lost != "" or hull.comps.is_empty():
		return
	for ship in ships:
		if ship.data.gun_range <= 0.0 or ship.is_sinking() or ship.passive:
			continue
		var knows := ship.alerted or ship.awareness > 0.6 or (ship.ai != null and ship.ai.mode >= ShipAI.Mode.SEARCH)
		var d := ship.pos.distance_to(sub.pos)
		if not knows or d > ship.data.gun_range:
			continue
		ship.gun_timer -= dt
		if ship.gun_timer > 0.0:
			continue
		ship.gun_timer = ship.data.gun_interval * rng.randf_range(0.8, 1.2)
		if ship.ai != null:
			ship.ai.report(sub.pos, 100.0, rng, 1.0)
		var p_hit := ship.data.gun_accuracy * lerpf(1.0, 0.1, d / ship.data.gun_range)
		if rng.randf() < p_hit:
			var z := rng.randf_range(hull.comps[0].z0, hull.comps[-1].z1)
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var dmg := hull.apply_blast(ship.data.gun_blast, z, side, rng)
			event.emit("blast", {"x": sub.pos.x, "y": sub.pos.y, "d": 0.0, "dist": ship.data.gun_blast, "dmg": dmg, "shell": true, "ship": ship.id})
		else:
			var miss := sub.pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(40.0, 250.0)
			event.emit("shell", {"x": miss.x, "y": miss.y, "ship": ship.id})


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
			info["class"] = ship.data.key
			info["role"] = ship.data.role
			event.emit("sunk", info)
		return


func to_snapshot() -> Dictionary:
	return {
		"t": time,
		"sub": sub.to_snapshot(),
		"ships": ships.map(func(s: ShipState) -> Dictionary: return s.to_snapshot()),
		"torps": torpedoes.map(func(t: Torpedo) -> Dictionary: return t.to_snapshot()),
		"dcs": charges.map(func(dc: DepthCharge) -> Array: return dc.to_snapshot()),
		"pl": planes.map(func(p: Aircraft) -> Array: return p.to_snapshot()),
		"wh": whales.map(func(wh: Whale) -> Array: return wh.to_snapshot()),
		"hull": hull.to_snapshot(),
		"air": air.to_snapshot(),
		"cd": conditions.to_snapshot(),
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
	var pls: Array[Aircraft] = []
	for a: Array in s.pl:
		var p := Aircraft.new()
		p.id = a[0]
		p.pos = a[1]
		p.heading = a[2]
		p.altitude = a[3]
		pls.append(p)
	planes = pls
	var whs: Array[Whale] = []
	for a: Array in s.get("wh", []):
		var wh := Whale.new()
		for old in whales:
			if old.id == a[0]:
				wh = old
		wh.apply_snapshot(a)
		whs.append(wh)
	whales = whs
	hull.apply_snapshot(s.hull)
	air.apply_snapshot(s.air)
	conditions.apply_snapshot(s.cd)
	lost = s.lost


func _take_id() -> int:
	_next_id += 1
	return _next_id - 1
