class_name Aircraft
extends RefCounted
## A patrol plane off a carrier (or a cruiser's floatplane). It flies search legs round its
## ship; a surfaced boat is seen from far off, a raised periscope or a shallow hull only close
## (and hardly at all at night). Seeing her, it calls the escorts in and dives to bomb.

enum Mode { SEARCH, ATTACK, HOME }

const SPEED := 70.0 ## m/s
const SEARCH_RADIUS := 9000.0
const ENDURANCE := 600.0 ## s aloft before it heads home
const SEE_SURFACED := 12000.0
const SEE_SCOPE := 2500.0
const SEE_SHALLOW := 700.0 ## a hull at periscope depth shows as a shadow in clear water
const CRUISE_ALT := 300.0
const ATTACK_ALT := 40.0

var id := 0
var pos := Vector2.ZERO
var heading := 0.0
var altitude := CRUISE_ALT
var mode := Mode.SEARCH
var home: ShipState
var fuel := ENDURANCE
var bombs := 2
var target := Vector2.ZERO
var _waypoint := Vector2.ZERO


func direction() -> Vector2:
	var rad := deg_to_rad(heading)
	return Vector2(sin(rad), cos(rad))


## How far off this plane sees the boat now.
static func sight_range(sub: SubState, c: Conditions) -> float:
	var r := 0.0
	if sub.is_surfaced():
		r = SEE_SURFACED
	elif sub.scope_height() > 0.0:
		r = SEE_SCOPE
	if sub.depth < 22.0:
		r = maxf(r, SEE_SHALLOW)
	return r * c.visual_factor() * lerpf(1.0, Conditions.RAIN_SIGHT, c.rain_at(sub.pos)) # a boat under a squall is hidden from above


## Host step. Returns true while it should stay in the world.
func step(dt: float, world: OceanWorld, rng: RandomNumberGenerator) -> bool:
	fuel -= dt
	var sub := world.sub
	if home == null or home.is_sinking():
		return false
	match mode:
		Mode.SEARCH:
			if pos.distance_to(_waypoint) < 400.0 or _waypoint == Vector2.ZERO:
				_waypoint = home.pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2000.0, SEARCH_RADIUS)
			_fly(_waypoint, dt)
			altitude = move_toward(altitude, CRUISE_ALT, 20.0 * dt)
			if pos.distance_to(sub.pos) < sight_range(sub, world.conditions) and world.lost == "":
				target = sub.pos
				mode = Mode.ATTACK
				world.raise_alarm(sub.pos, 150.0, 0.9)
				world.event.emit("aircraft", {"id": id, "x": pos.x, "y": pos.y, "spotted": true})
			elif fuel <= 0.0:
				mode = Mode.HOME
		Mode.ATTACK:
			# Keep the aim on where she was last seen, nudged while she's still visible.
			if pos.distance_to(sub.pos) < sight_range(sub, world.conditions) * 1.2:
				target = sub.pos
			_fly(target, dt)
			altitude = move_toward(altitude, ATTACK_ALT, 40.0 * dt)
			if pos.distance_to(target) < 60.0 and bombs > 0:
				bombs -= 1
				world.drop_charge(pos, maxf(sub.depth, 12.0) if sub.depth < 30.0 else 15.0, 1.2)
				world.event.emit("splash", {"ship": -1, "x": pos.x, "y": pos.y})
				_waypoint = pos + direction() * 2500.0
				if bombs == 0:
					mode = Mode.HOME
			elif pos.distance_to(target) < 60.0:
				mode = Mode.HOME
		Mode.HOME:
			_fly(home.pos, dt)
			altitude = move_toward(altitude, CRUISE_ALT, 20.0 * dt)
			if pos.distance_to(home.pos) < 300.0:
				return false
	return true


func _fly(to: Vector2, dt: float) -> void:
	var want := ShipState.bearing(pos, to)
	var turn := wrapf(want - heading, -180.0, 180.0)
	heading = fposmod(heading + clampf(turn, -12.0 * dt, 12.0 * dt), 360.0)
	pos += direction() * SPEED * dt


func to_snapshot() -> Array:
	return [id, pos, heading, altitude]
