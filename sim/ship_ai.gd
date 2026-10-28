class_name ShipAI
extends RefCounted
## Anti-submarine brain for an escort (host only). A small state machine:
##   PATROL  keep station on the convoy, listen
##   SEARCH  something is out there: head for the rough position, slow, ping
##   HUNT    echo contact: close in, keep pinging to refine it
##   ATTACK  sprint over the predicted position (sonar is blind this close)
##   OPEN    roll the pattern, run out, then turn back and hunt again
## The decision only sets course and ordered speed; ShipState.step does the motion.

enum Mode { PATROL, SEARCH, HUNT, ATTACK, OPEN }
const MODE_NAMES := ["patrolling", "searching", "hunting", "attacking", "attacking"]

const SEARCH_KN := 14.0 ## slow enough for the sonar to work
const SUSPICIOUS := 0.35
const DECAY := 0.004 ## awareness lost per second when nothing is noticed
const LOSE_CONTACT := 90.0 ## s without a fix before a hunt becomes a search
const ATTACK_RANGE := 1000.0
const RUN_OUT := 35.0 ## s of running straight after a pattern

var ship: ShipState
var mode := Mode.PATROL
var guard: ShipState ## the ship it escorts, if any
var guard_offset := Vector2.ZERO ## (right, ahead) of the guard, metres
var dc_left := 0
var contact_pos := Vector2.ZERO
var contact_vel := Vector2.ZERO
var contact_depth := 30.0
var contact_age := INF
var mode_time := 0.0
var _ping_timer := 0.0
var _fix_timer := 0.0
var _drops := 0
var _drop_timer := 0.0
var _search_point := Vector2.ZERO
var _last_dist := INF
var _clock := 0.0
var _ref_pos := Vector2.ZERO ## an older fix, for estimating the sub's course and speed
var _ref_time := -INF


func _init(s: ShipState) -> void:
	ship = s
	dc_left = s.data.depth_charges
	s.ai = self


func set_mode(m: Mode) -> void:
	mode = m
	ship.mode = m
	mode_time = 0.0
	_last_dist = INF


## A report of the sub from outside (a lookout's call, a torpedo wake, a radioed hit).
func report(pos: Vector2, error: float, rng: RandomNumberGenerator, awareness := 0.6) -> void:
	ship.awareness = maxf(ship.awareness, awareness)
	if mode >= Mode.HUNT and contact_age < LOSE_CONTACT:
		return
	_set_contact(pos, error, 30.0, rng)
	set_mode(Mode.HUNT if awareness >= 0.8 else Mode.SEARCH)
	_search_point = contact_pos


func step(dt: float, world: OceanWorld, rng: RandomNumberGenerator) -> void:
	var sub := world.sub
	mode_time += dt
	contact_age += dt
	_clock += dt
	var gain := Detection.awareness_gain(ship, sub)
	ship.awareness = clampf(ship.awareness + (gain - DECAY) * dt, 0.0, 1.0)
	_fix_timer -= dt
	if mode != Mode.PATROL and gain > 0.006 and _fix_timer <= 0.0:
		# Seen or clearly heard: a rough fix without pinging.
		_fix_timer = 5.0
		_set_contact(sub.pos, ship.pos.distance_to(sub.pos) * 0.08, 20.0, rng, sub.depth)
	_update_pattern(dt, world, rng)

	match mode:
		Mode.PATROL:
			_patrol()
			if ship.awareness > SUSPICIOUS:
				# Rough idea from a bearing: right direction, wrong distance.
				var d := ship.pos.distance_to(sub.pos)
				var b := deg_to_rad(ShipState.bearing(ship.pos, sub.pos) + rng.randf_range(-15.0, 15.0))
				_set_contact(ship.pos + Vector2(sin(b), cos(b)) * d * rng.randf_range(0.6, 1.4), 0.0, 40.0, rng)
				_search_point = contact_pos
				set_mode(Mode.SEARCH)
		Mode.SEARCH:
			if ship.pos.distance_to(_search_point) < 250.0:
				_search_point = contact_pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(200.0, 800.0)
			_steer(_search_point, SEARCH_KN)
			_ping(dt, world, rng)
			if ship.awareness < 0.15 and mode_time > 60.0:
				set_mode(Mode.PATROL)
		Mode.HUNT:
			var aim := predicted()
			var d := ship.pos.distance_to(aim)
			_steer(aim, ship.data.hunt_speed_kn if d > 1600.0 else SEARCH_KN)
			_ping(dt, world, rng)
			if d < ATTACK_RANGE and contact_age < 20.0 and dc_left > 0:
				set_mode(Mode.ATTACK)
			elif contact_age > LOSE_CONTACT:
				_search_point = contact_pos
				set_mode(Mode.SEARCH)
		Mode.ATTACK:
			var aim := predicted()
			var d := ship.pos.distance_to(aim)
			# Slow enough to keep pinging until the last stretch, then sprint over him.
			_steer(aim, ship.data.max_speed_kn * 0.8 if d < 500.0 else SEARCH_KN + 4.0)
			if d > 400.0:
				_ping(dt, world, rng)
			if d < 60.0 or (d < 220.0 and d > _last_dist) or mode_time > 120.0:
				_drops = mini(ship.data.dc_pattern, dc_left)
				_drop_timer = 0.0
				world.event.emit("splash", {"ship": ship.id, "x": ship.pos.x, "y": ship.pos.y})
				set_mode(Mode.OPEN)
			_last_dist = d
		Mode.OPEN:
			ship.ordered_speed = ship.data.max_speed_kn * 0.8 * SubState.KNOT
			if mode_time > RUN_OUT:
				set_mode(Mode.HUNT if dc_left > 0 or contact_age < LOSE_CONTACT else Mode.SEARCH)


## Where it thinks the sub is now.
func predicted() -> Vector2:
	return contact_pos + contact_vel * minf(contact_age, 60.0)


func _set_contact(pos: Vector2, error: float, depth_error: float, rng: RandomNumberGenerator, depth := -1.0) -> void:
	var p := pos + Vector2(rng.randfn(0.0, error), rng.randfn(0.0, error))
	# Course and speed from fixes at least 20 s apart, smoothed; noisy fixes close together
	# would give wild speeds.
	var span := _clock - _ref_time
	if span > 90.0:
		contact_vel = Vector2.ZERO
		_ref_pos = p
		_ref_time = _clock
	elif span >= 20.0:
		contact_vel = contact_vel.lerp(((p - _ref_pos) / span).limit_length(5.0), 0.6)
		_ref_pos = p
		_ref_time = _clock
	contact_pos = p
	contact_age = 0.0
	if depth >= 0.0:
		contact_depth = maxf(10.0, depth + rng.randf_range(-depth_error, depth_error))


func _ping(dt: float, world: OceanWorld, rng: RandomNumberGenerator) -> void:
	if ship.data.sonar_range <= 0.0:
		return
	_ping_timer -= dt
	if _ping_timer > 0.0:
		return
	_ping_timer = ship.data.ping_interval
	var sub := world.sub
	var echo := rng.randf() < Detection.ping_chance(ship, sub)
	world.event.emit("ping", {"ship": ship.id, "x": ship.pos.x, "y": ship.pos.y, "echo": echo})
	if echo:
		ship.awareness = 1.0
		_set_contact(sub.pos, ship.pos.distance_to(sub.pos) * 0.03, ship.data.depth_error, rng, sub.depth)
		if mode == Mode.SEARCH:
			set_mode(Mode.HUNT)


func _update_pattern(dt: float, world: OceanWorld, rng: RandomNumberGenerator) -> void:
	if _drops <= 0:
		return
	_drop_timer -= dt
	if _drop_timer > 0.0:
		return
	_drop_timer = 0.9
	_drops -= 1
	dc_left -= 1
	# Rolled off the stern racks, every third one thrown wide by a K-gun.
	var back := -ship.direction() * ship.data.length * 0.5
	var side := Vector2(ship.direction().y, -ship.direction().x)
	var throw := 0.0
	if _drops % 3 == 1:
		throw = 45.0 if (_drops / 3) % 2 == 0 else -45.0
	world.drop_charge(ship.pos + back + side * throw + Vector2(rng.randfn(0, 4), rng.randfn(0, 4)),
		contact_depth + rng.randf_range(-4.0, 4.0))


func _patrol() -> void:
	if guard == null or guard.is_sinking():
		_steer(ship.pos + ship.direction() * 1000.0, ship.data.cruise_speed_kn)
		return
	var fwd := guard.direction()
	var right := Vector2(fwd.y, -fwd.x)
	var spot := guard.pos + right * guard_offset.x + fwd * guard_offset.y
	var d := ship.pos.distance_to(spot)
	if d > 150.0:
		var kn := clampf(guard.speed / SubState.KNOT + d / 100.0, ship.data.cruise_speed_kn * 0.5, ship.data.max_speed_kn * 0.7)
		_steer(spot, kn)
	else:
		ship.course = guard.heading
		ship.ordered_speed = guard.speed


func _steer(target: Vector2, kn: float) -> void:
	ship.course = ShipState.bearing(ship.pos, target)
	ship.ordered_speed = kn * SubState.KNOT
