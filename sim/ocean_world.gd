class_name OceanWorld
extends RefCounted
## The whole ocean simulation, with no rendering: the sub, AI ships and torpedoes.
## The host steps it authoritatively; clients step it between snapshots for smoothness.

## kind: "fired" | "hit" | "dud" | "sunk". Only emitted by authoritative steps.
signal event(kind: String, data: Dictionary)

const SHIP_DIR := "res://data/ships/%s.tres"

var time := 0.0
var sub: SubState
var ships: Array[ShipState] = []
var torpedoes: Array[Torpedo] = []
var dud_chance := 0.05
var rng := RandomNumberGenerator.new()
var _next_id := 1


func _init(sub_class: SubClassData, seed_value := 0) -> void:
	sub = SubState.new(sub_class)
	rng.seed = seed_value


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
	return ship


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
	return t


func step(dt: float, authoritative := true) -> void:
	time += dt
	sub.step(dt)
	for ship in ships:
		ship.step(dt, rng if authoritative else null)
	for t in torpedoes:
		t.step(dt)
		if authoritative and t.alive:
			_check_hits(t)
	torpedoes = torpedoes.filter(func(t: Torpedo) -> bool: return t.alive)
	if authoritative:
		ships = ships.filter(func(s: ShipState) -> bool: return s.sink < 1.0)


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


func _take_id() -> int:
	_next_id += 1
	return _next_id - 1
