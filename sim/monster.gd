class_name Monster
extends RefCounted
## Things that live in the depths (Blaney: "terrifying sea creatures that live in the depths that
## can be hunted, or that can hunt us"): a giant squid, a giant anglerfish, a sea serpent and a
## megalodon. Each keeps below its own depth. It wanders down there until it hears the boat (a
## noisy boat from further off), stalks her, calling, then comes in: the squid wraps the hull and
## squeezes, the anglerfish bites, the serpent strikes again and again, the megalodon rams. Then
## it backs off into the dark and comes again. Take her up above its depth and it gives up; a
## torpedo hurts it, enough of them kill it. Creepy dread, no gore (Blaney).
## One called up on the PA (`hunting`) comes up to any boat, a WWII boat at periscope depth
## too (Blaney); only surfacing shakes it off. They always swim faster than the boat, so
## running away at slow ahead doesn't leave them behind.

const KINDS := {
	"squid": {"name": "giant squid", "length": 40.0, "hp": 2, "speed": 5.0, "floor": 200.0, "act": "grab"},
	"angler": {"name": "giant anglerfish", "length": 28.0, "hp": 2, "speed": 4.0, "floor": 280.0, "act": "bite"},
	"serpent": {"name": "sea serpent", "length": 90.0, "hp": 3, "speed": 8.0, "floor": 120.0, "act": "strike"},
	"megalodon": {"name": "megalodon", "length": 45.0, "hp": 3, "speed": 9.0, "floor": 60.0, "act": "ram"},
}
const HEAR := 1500.0 ## m it hears even a quiet boat; a loud one much further
const STALK_RANGE := 260.0 ## m it circles at before it comes in
const HOLD_TIME := 18.0 ## s the squid holds on
const SQUEEZE_EVERY := 5.0
const STRIKES := 3 ## the serpent's strikes in one attack
const HUNT_FLOOR := 15.0 ## m: how shallow one called up on the PA comes
const EDGE := 2.0 ## m/s it stalks faster than the boat; attacking, EDGE * 2.5

var id := 0
var kind := "squid"
var pos := Vector2.ZERO
var depth := 300.0
var heading := 0.0
var speed := 0.0
var hp := 2
var state := "lurk" ## lurk, stalk, attack, hold, retreat, dead
var hunting := false ## called up on the PA: it comes for us from the start
var _timer := 0.0
var _course := 0.0
var _hits := 0
var _call := 0.0


static func make(k: String) -> Monster:
	var m := Monster.new()
	m.kind = k if KINDS.has(k) else "squid"
	m.hp = int(KINDS[m.kind].hp)
	return m


func info() -> Dictionary:
	return KINDS[kind]


func length() -> float:
	return float(info().length)


## The shallowest it will come: below this it lives, above it gives up the chase.
func floor_depth() -> float:
	return HUNT_FLOOR if hunting else float(info().floor)


func is_dead() -> bool:
	return state == "dead"


## Host: one step of its brain. Events (`emit`) are the sim's: "monster" with an act.
func think(dt: float, w: OceanWorld) -> void:
	var sub := w.sub
	var rng := w.rng
	var to_sub := sub.pos - pos
	var dist := maxf(0.0, Vector3(to_sub.x, sub.depth - depth, to_sub.y).length() - sub.data.length * 0.4)
	var reachable := sub.depth > floor_depth() - 20.0 and not (hunting and sub.is_surfaced())
	_timer -= dt
	_call -= dt
	var want_depth := depth
	var want_speed := float(info().speed) * 0.3
	match state:
		"dead":
			depth += 2.0 * dt # it sinks away into the dark
			speed = move_toward(speed, 0.0, dt)
			return
		"lurk":
			if _timer <= 0.0:
				_course = fposmod(heading + rng.randf_range(-90.0, 90.0), 360.0)
				_timer = rng.randf_range(30.0, 90.0)
			want_depth = maxf(floor_depth() + 120.0, minf(depth, w.seabed.floor_depth(pos) - 20.0))
			var noise := Detection.sub_noise(sub)
			if reachable and (hunting or dist < HEAR * (0.6 + noise * 2.0)):
				_go("stalk", rng.randf_range(25.0, 45.0))
		"stalk": # circle in the dark, calling, closing
			if not reachable:
				_give_up(w)
				return
			var round := Vector2(-to_sub.y, to_sub.x).normalized() * (1.0 if id % 2 == 0 else -1.0)
			var closing := to_sub.normalized() * (1.0 if dist > STALK_RANGE else -0.3)
			_course = _bearing(closing + round * (0.8 if dist < STALK_RANGE * 2.0 else 0.25)) # far off it comes straight on
			want_depth = clampf(sub.depth + 25.0, floor_depth(), 3000.0)
			want_speed = maxf(float(info().speed) * 0.6, absf(sub.speed) + EDGE)
			if _call <= 0.0:
				_call = rng.randf_range(12.0, 25.0)
				_emit(w, "call", {})
			if _timer <= 0.0 and dist < STALK_RANGE * 1.6:
				_go("attack", 60.0)
				_emit(w, "charge", {})
		"attack": # straight in, fast
			if not reachable:
				_give_up(w)
				return
			_course = _bearing(to_sub)
			want_depth = sub.depth
			want_speed = maxf(float(info().speed) * 2.0, absf(sub.speed) + EDGE * 2.5)
			if dist < maxf(length() * 0.25, 10.0):
				_strike(w, to_sub)
			elif _timer <= 0.0:
				_go("stalk", 20.0)
		"hold": # the squid's arms round the hull: she's dragged to a stop, squeezed
			pos = sub.pos - sub.direction() * 5.0
			depth = sub.depth + 4.0
			heading = sub.heading
			speed = sub.speed
			sub.speed = move_toward(sub.speed, 0.0, 1.5 * dt)
			if fmod(_timer, SQUEEZE_EVERY) < dt:
				_hurt_boat(w, 28.0, "squeeze", Vector2.ZERO)
			if _timer <= 0.0 or not reachable:
				_emit(w, "release", {})
				_go("retreat", rng.randf_range(50.0, 80.0))
			return
		"retreat": # off into the dark, then back
			_course = _bearing(-to_sub)
			want_depth = sub.depth + 80.0
			want_speed = maxf(float(info().speed), absf(sub.speed) + EDGE)
			if _timer <= 0.0:
				_go("stalk" if reachable else "lurk", rng.randf_range(20.0, 40.0))
	want_depth = minf(want_depth, maxf(floor_depth(), w.seabed.floor_depth(pos) - 10.0))
	speed = move_toward(speed, want_speed, 2.0 * dt)
	heading = fposmod(heading + clampf(wrapf(_course - heading, -180.0, 180.0), -25.0 * dt, 25.0 * dt), 360.0)
	depth = move_toward(depth, maxf(want_depth, floor_depth()), 4.0 * dt)
	pos += Vector2(sin(deg_to_rad(heading)), cos(deg_to_rad(heading))) * speed * dt


## Clients: carry on along its heading between snapshots.
func coast(dt: float) -> void:
	pos += Vector2(sin(deg_to_rad(heading)), cos(deg_to_rad(heading))) * speed * dt


func _strike(w: OceanWorld, to_sub: Vector2) -> void:
	match info().act:
		"grab":
			_emit(w, "grab", {})
			_go("hold", HOLD_TIME)
			_hurt_boat(w, 30.0, "squeeze", to_sub)
		"strike":
			_hurt_boat(w, 30.0, "strike", to_sub)
			_hits += 1
			if _hits >= STRIKES:
				_hits = 0
				_go("retreat", w.rng.randf_range(50.0, 80.0))
			else:
				_go("attack", 12.0)
				pos -= to_sub.normalized() * 60.0 # it draws back to strike again
		"bite":
			_hurt_boat(w, 18.0, "bite", to_sub)
			_go("retreat", w.rng.randf_range(50.0, 80.0))
		_:
			_hurt_boat(w, 12.0, "ram", to_sub)
			_go("retreat", w.rng.randf_range(60.0, 90.0))


## Damage to the boat as from a blast `dist` metres off, where it struck.
func _hurt_boat(w: OceanWorld, dist: float, act: String, to_sub: Vector2) -> void:
	var sub := w.sub
	var dmg: Array[String] = []
	if not w.hull.comps.is_empty() and w.lost == "":
		var along := clampf(-to_sub.dot(sub.direction()) / sub.data.length, -0.5, 0.5) if to_sub != Vector2.ZERO else w.rng.randf_range(-0.4, 0.4)
		var side := signf(-to_sub.dot(Vector2(sub.direction().y, -sub.direction().x)))
		var z0: float = w.hull.comps[0].z0
		var z1: float = w.hull.comps[-1].z1
		dmg = w.hull.apply_blast(dist, lerpf(z1, z0, along + 0.5), side if side != 0.0 else 1.0, w.rng)
	_emit(w, act, {"dist": dist, "dmg": dmg})


## A torpedo (or anything else) hits it. Returns true if that killed it.
func wounded(w: OceanWorld) -> bool:
	hp -= 1
	if hp <= 0:
		state = "dead"
		_emit(w, "dead", {})
		return true
	_emit(w, "hurt", {})
	_go("retreat", 40.0)
	return false


func _give_up(w: OceanWorld) -> void:
	_emit(w, "give_up", {})
	hunting = false
	_go("lurk", 60.0)


func _go(s: String, t: float) -> void:
	state = s
	_timer = t


func _emit(w: OceanWorld, act: String, extra: Dictionary) -> void:
	var d := {"act": act, "kind": kind, "name": info().name, "id": id, "x": pos.x, "y": pos.y, "d": depth}
	d.merge(extra)
	w.event.emit("monster", d)


static func _bearing(v: Vector2) -> float:
	return fposmod(rad_to_deg(atan2(v.x, v.y)), 360.0)


## What the hydrophones make of it, 0..1: a low groaning call when it's near, louder hunting.
func loudness(sub: SubState, hear_range: float) -> float:
	var d := pos.distance_to(sub.pos)
	if d > hear_range or is_dead():
		return 0.0
	var base := 0.25 if state == "lurk" else 0.7
	return clampf(base * (1.0 - d / hear_range) * 1.8, 0.0, 1.0)


func to_snapshot() -> Array:
	return [id, kind, pos, depth, heading, speed, state]


func apply_snapshot(a: Array) -> void:
	id = a[0]
	kind = a[1]
	pos = a[2]
	depth = a[3]
	heading = a[4]
	speed = a[5]
	state = a[6]
