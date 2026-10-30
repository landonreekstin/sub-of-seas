class_name Whale
extends RefCounted
## A humpback wandering the patrol area: slow, deep for a while, then up to breathe, and now
## and then singing. To the hydrophones and an active ping it is a contact like any ship, so
## it is the sonar operator's ear that tells it apart (lando: whales as false positives).

const SPEED := 1.6 ## m/s, cruising
const LENGTH := 15.0

var id := 0
var pos := Vector2.ZERO
var heading := 0.0
var depth := 30.0
var singing := false
var _course := 0.0
var _turn_timer := 0.0
var _breath := 0.0 ## seconds into its dive cycle
var _song_timer := 0.0


## `rng` only on the host: it decides where to wander and when to sing; clients interpolate.
func step(dt: float, rng: RandomNumberGenerator) -> void:
	if rng != null:
		_turn_timer -= dt
		if _turn_timer <= 0.0:
			_course = fposmod(heading + rng.randf_range(-70.0, 70.0), 360.0)
			_turn_timer = rng.randf_range(40.0, 120.0)
		_song_timer -= dt
		if _song_timer <= 0.0:
			singing = not singing
			_song_timer = rng.randf_range(30.0, 90.0) if singing else rng.randf_range(40.0, 140.0)
		# Six minutes down, about a minute up blowing at the surface.
		_breath = fposmod(_breath + dt, 420.0)
		var target := 0.0 if _breath > 360.0 else 35.0
		depth = move_toward(depth, target, 0.8 * dt)
	heading = fposmod(heading + clampf(wrapf(_course - heading, -180.0, 180.0), -3.0 * dt, 3.0 * dt), 360.0)
	pos += Vector2(sin(deg_to_rad(heading)), cos(deg_to_rad(heading))) * SPEED * dt


## What the hydrophones make of it, 0..1: faint swimming, much louder singing.
func loudness(sub: SubState, hear_range: float) -> float:
	var d := pos.distance_to(sub.pos)
	if d > hear_range:
		return 0.0
	var own := absf(sub.speed) / (sub.data.submerged_speed_kn * SubState.KNOT)
	return clampf((0.75 if singing else 0.25) * (1.0 - d / hear_range) * 1.6 - own * 0.35, 0.0, 1.0)


func to_snapshot() -> Array:
	return [id, pos, heading, depth, singing]


func apply_snapshot(a: Array) -> void:
	id = a[0]
	pos = a[1]
	heading = a[2]
	_course = heading
	depth = a[3]
	singing = a[4]
