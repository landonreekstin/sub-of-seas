class_name ShipState
extends RefCounted
## One AI surface ship in the ocean simulation. Same coordinates as SubState.

var id := 0
var data: ShipClassData
var pos := Vector2.ZERO
var heading := 0.0
var course := 0.0 ## heading the ship is steering for
var base_course := 0.0 ## the course its zig-zag legs are centred on
var speed := 0.0
var ordered_speed := 0.0
var hp := 1.0
var sink := 0.0 ## 0 afloat .. 1 gone
var alerted := false
var awareness := 0.0 ## 0..1, how sure it is that a sub is near (see Detection)
var ai: ShipAI = null ## host only, for anti-submarine ships
var mode := 0 ## ShipAI.Mode, replicated so stations can show it
var passive := false ## scripted (training): no lookouts, no zig-zag, holds course and speed
var _zig_timer := 30.0


func _init(ship_class: ShipClassData) -> void:
	data = ship_class
	hp = ship_class.hp


func is_sinking() -> bool:
	return hp <= 0.0


func direction() -> Vector2:
	var rad := deg_to_rad(heading)
	return Vector2(sin(rad), cos(rad))


## Distance from a point to the ship's centreline (a segment bow to stern).
func distance_to_hull(p: Vector2) -> float:
	var half := direction() * data.length * 0.5
	return Geometry2D.get_closest_point_to_segment(p, pos - half, pos + half).distance_to(p)


## `rng` is only passed on the host: decisions (zig-zag legs) are made there and replicated.
func step(dt: float, rng: RandomNumberGenerator) -> void:
	if is_sinking():
		ordered_speed = 0.0
		sink = minf(1.0, sink + dt / data.sink_time)
	elif ai != null or passive:
		pass # the AI (or a script) sets course and speed
	elif rng != null:
		_zig_timer -= dt
		if _zig_timer <= 0.0:
			var leg := data.zigzag_angle * (2.0 if alerted else 1.0)
			course = fposmod(base_course + rng.randf_range(-leg, leg), 360.0)
			_zig_timer = rng.randf_range(40.0, 90.0) * (0.5 if alerted else 1.0)
	speed = move_toward(speed, ordered_speed, 0.3 * dt)
	var turn := wrapf(course - heading, -180.0, 180.0)
	var max_turn := data.max_turn_rate * dt
	heading = fposmod(heading + clampf(turn, -max_turn, max_turn), 360.0)
	pos += direction() * speed * dt


func alert() -> void:
	if alerted or is_sinking():
		return
	alerted = true
	ordered_speed = data.max_speed_kn * SubState.KNOT
	_zig_timer = 0.0


func to_snapshot() -> Dictionary:
	return {
		"id": id, "k": data.key, "p": pos, "h": heading, "c": course,
		"s": speed, "os": ordered_speed, "hp": hp, "sk": sink, "m": mode,
	}


func apply_snapshot(s: Dictionary) -> void:
	pos = s.p
	heading = s.h
	course = s.c
	speed = s.s
	ordered_speed = s.os
	hp = s.hp
	sink = s.sk
	mode = s.m


static func bearing(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return fposmod(rad_to_deg(atan2(d.x, d.y)), 360.0)
