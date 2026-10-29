class_name HullState
extends RefCounted
## Damage state inside the boat, in interior coordinates (bow is -Z, deck at y 0):
## water per compartment, leaks, fires, portable pumps and broken stations.
## Host-authoritative; replicated in the sim snapshot.

const DECK_HEIGHT := 2.6
const FLOW := 0.6 ## volume per second per unit of level difference through an open door
const PUMP_RATE := 0.05 ## volume per second per portable pump
const FIRE_GROWTH := 0.012 ## size per second
const FIRE_MAX_PER_ROOM := 3
const LEAK_SIZES := [0.03, 0.06, 0.12] ## volume per second; a 14 m room holds 14
const TORCH_SECONDS_PER_RATE := 75.0 ## 0.03 leak = 2.3 s of welding, 0.12 = 9 s
const WRENCH_SECONDS := 6.0

## Each: {name, z0, z1, water (0..1 of deck height)}.
var comps: Array[Dictionary] = []
var links := {} ## door_id -> [comp_a, comp_b]
var doors_open := {} ## door_id -> bool, set by the host from crew state
var station_comp := {} ## station_id -> comp index
var leaks: Array[Dictionary] = [] ## {id, c, p: Vector3, rate, hp}
var fires: Array[Dictionary] = [] ## {id, c, p: Vector3, size}
var pumps: Array[Dictionary] = [] ## {c, p: Vector3}
var broken := {} ## station_id -> seconds of wrench work left
var _next_id := 1


func setup(compartments: Array, door_links: Dictionary, stations := {}) -> HullState:
	comps.clear()
	for c: Dictionary in compartments:
		comps.append({"name": c.name, "z0": c.z0, "z1": c.z1, "water": 0.0})
	links = door_links.duplicate()
	for d: String in links:
		doors_open[d] = true
	station_comp = stations.duplicate()
	return self


func comp_at(z: float) -> int:
	for i in comps.size():
		if z >= comps[i].z0 and z < comps[i].z1:
			return i
	return 0 if z < 0.0 else comps.size() - 1


func length(c: int) -> float:
	return comps[c].z1 - comps[c].z0


## Fraction of the hull's total volume that is seawater.
func water_fraction() -> float:
	var vol := 0.0
	var cap := 0.0
	for i in comps.size():
		vol += comps[i].water * length(i)
		cap += length(i)
	return vol / cap if cap > 0.0 else 0.0


func step(dt: float, rng: RandomNumberGenerator) -> void:
	for l in leaks:
		_add_water(l.c, l.rate * dt)
	for p in pumps:
		_add_water(p.c, -PUMP_RATE * dt)
	for d: String in links:
		if not doors_open.get(d, false):
			continue
		var a: int = links[d][0]
		var b: int = links[d][1]
		var v: float = (comps[a].water - comps[b].water) * FLOW * dt
		v = clampf(v, -comps[b].water * length(b), comps[a].water * length(a))
		_add_water(a, -v)
		_add_water(b, v)
	_step_fires(dt, rng)


func _add_water(c: int, volume: float) -> void:
	comps[c].water = clampf(comps[c].water + volume / length(c), 0.0, 1.0)


func _step_fires(dt: float, rng: RandomNumberGenerator) -> void:
	var spread: Array[int] = []
	for f in fires:
		f.size = minf(1.0, f.size + FIRE_GROWTH * dt)
		if comps[f.c].water * DECK_HEIGHT > 0.45:
			f.size = 0.0 # drowned
		if f.size > 0.7 and rng.randf() < 0.01 * dt:
			spread.append(f.c)
		if f.size > 0.85:
			for d: String in links:
				var pair: Array = links[d]
				if doors_open.get(d, false) and f.c in pair and rng.randf() < 0.02 * dt:
					spread.append(pair[1] if pair[0] == f.c else pair[0])
		if f.size > 0.5:
			for sid: String in station_comp:
				if station_comp[sid] == f.c and not broken.has(sid) and rng.randf() < 0.004 * dt:
					broken[sid] = WRENCH_SECONDS
	fires = fires.filter(func(f: Dictionary) -> bool: return f.size > 0.0)
	for c in spread:
		add_fire(c, rng)


func fires_in(c: int) -> int:
	return fires.filter(func(f: Dictionary) -> bool: return f.c == c).size()


func add_leak(c: int, size: int, rng: RandomNumberGenerator, side := 0.0) -> Dictionary:
	if side == 0.0:
		side = -1.0 if rng.randf() < 0.5 else 1.0
	var rate: float = LEAK_SIZES[clampi(size, 0, LEAK_SIZES.size() - 1)]
	var leak := {
		"id": _take_id(), "c": c, "rate": rate, "hp": rate * TORCH_SECONDS_PER_RATE,
		"p": Vector3(side * 1.88, rng.randf_range(0.5, 2.1), _random_z(c, rng)),
	}
	leaks.append(leak)
	return leak


func add_fire(c: int, rng: RandomNumberGenerator) -> Dictionary:
	if fires_in(c) >= FIRE_MAX_PER_ROOM:
		return {}
	var fire := {
		"id": _take_id(), "c": c, "size": 0.25,
		"p": Vector3(rng.randf_range(-1.2, 1.2), 0.0, _random_z(c, rng)),
	}
	fires.append(fire)
	return fire


func _random_z(c: int, rng: RandomNumberGenerator) -> float:
	return rng.randf_range(comps[c].z0 + 0.8, comps[c].z1 - 0.8)


## Damage from a depth charge `dist` metres away (3D), centred on interior z `at_z` on
## side `side` (-1 port, 1 starboard). Returns what happened, for announcements.
func apply_blast(dist: float, at_z: float, side: float, rng: RandomNumberGenerator) -> Array[String]:
	var out: Array[String] = []
	var c := comp_at(at_z)
	var leak_count := 0
	var leak_size := 0
	var fire_p := 0.0
	var break_p := 0.0
	if dist < DepthCharge.LETHAL:
		leak_count = 3
		leak_size = 2
		fire_p = 0.6
		break_p = 0.8
	elif dist < DepthCharge.HEAVY:
		leak_count = 1 + int(rng.randf() < 0.5)
		leak_size = 1
		fire_p = 0.3
		break_p = 0.4
	elif dist < DepthCharge.LIGHT:
		leak_count = int(rng.randf() < 0.4)
		fire_p = 0.08
		break_p = 0.1
	for i in leak_count:
		# Neighbouring rooms take some of a close blast.
		var lc := c if i == 0 else clampi(c + rng.randi_range(-1, 1), 0, comps.size() - 1)
		add_leak(lc, leak_size if i == 0 else maxi(0, leak_size - 1), rng, side)
		out.append("Leak in the %s!" % comps[lc].name)
	if rng.randf() < fire_p and not add_fire(c, rng).is_empty():
		out.append("Fire in the %s!" % comps[c].name)
	if rng.randf() < break_p:
		var here: Array = station_comp.keys().filter(func(s: String) -> bool:
			return station_comp[s] == c and not broken.has(s))
		if not here.is_empty():
			var sid: String = here[rng.randi() % here.size()]
			broken[sid] = WRENCH_SECONDS
			out.append("BROKEN:" + sid)
	return out


## Hands-on repair work from a tool. Returns true when the job is finished.
func work(tool: String, target: String, seconds: float) -> bool:
	match tool:
		"torch":
			for l in leaks:
				if str(l.id) == target:
					l.hp -= seconds
					if l.hp <= 0.0:
						leaks.erase(l)
						return true
					return false
		"extinguisher":
			for f in fires:
				if str(f.id) == target:
					f.size -= seconds * 0.3
					if f.size <= 0.0:
						fires.erase(f)
						return true
					return false
		"wrench":
			if broken.has(target):
				broken[target] -= seconds
				if broken[target] <= 0.0:
					broken.erase(target)
					return true
	return false


func is_broken(station_id: String) -> bool:
	return broken.has(station_id)


func to_snapshot() -> Dictionary:
	return {
		"w": comps.map(func(c: Dictionary) -> float: return c.water),
		"l": leaks, "f": fires, "pu": pumps, "b": broken,
	}


func apply_snapshot(s: Dictionary) -> void:
	for i in mini(comps.size(), s.w.size()):
		comps[i].water = s.w[i]
	leaks.assign(s.l)
	fires.assign(s.f)
	pumps.assign(s.pu)
	broken = s.b


func _take_id() -> int:
	_next_id += 1
	return _next_id - 1
