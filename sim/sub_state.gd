class_name SubState
extends RefCounted
## The player submarine as the ocean simulation sees it.
## Plane coordinates in metres: x east, y north. Heading in degrees, 0 = north, clockwise.

const KNOT := 0.514444
## Engine telegraph positions and the fraction of max speed each one orders.
const TELEGRAPH := {
	-2: -0.5, -1: -0.25, 0: 0.0, 1: 0.25, 2: 0.5, 3: 0.75, 4: 1.0,
}
const TELEGRAPH_NAMES := {
	-2: "BACK FULL", -1: "BACK 1/3", 0: "ALL STOP", 1: "AHEAD 1/3",
	2: "AHEAD 2/3", 3: "AHEAD STANDARD", 4: "AHEAD FLANK",
}
const RUDDER_DEGREES: Array[float] = [0.0, 10.0, 20.0, 35.0]

var data: SubClassData
var pos := Vector2.ZERO
var heading := 0.0
var speed := 0.0 ## m/s through the water, negative astern
var depth := 0.0 ## keel depth in metres, 0 = surfaced
var ordered_depth := 0.0
var telegraph := 0 ## key of TELEGRAPH
var rudder := 0 ## -3 (full left) .. 3 (full right), index into RUDDER_DEGREES
var periscope_raised := false
var turn_rate := 0.0 ## deg/s, for interior roll
var pitch := 0.0 ## degrees, nose up positive, for interior tilt
var heaviness := 0.0 ## fraction of the hull flooded; set by the world from the hull


func _init(sub_class: SubClassData) -> void:
	data = sub_class


func is_surfaced() -> bool:
	return depth < 1.0


func max_speed() -> float:
	return (data.surface_speed_kn if is_surfaced() else data.submerged_speed_kn) * KNOT


func rudder_angle() -> float:
	return signf(rudder) * RUDDER_DEGREES[absi(rudder)]


func direction() -> Vector2:
	var rad := deg_to_rad(heading)
	return Vector2(sin(rad), cos(rad))


## Height of the periscope head above the water (negative = under). Surfaced, it is the
## bridge height, so the scope doubles as the lookout view.
func scope_height() -> float:
	if is_surfaced():
		return 9.0
	if not periscope_raised:
		return -99.0
	return data.periscope_depth + 3.0 - depth


func step(dt: float) -> void:
	var target_speed: float = max_speed() * TELEGRAPH[telegraph]
	speed = move_toward(speed, target_speed, data.acceleration * dt)

	# Rudder and planes need water flowing over them.
	var flow := clampf(absf(speed) / (4.0 * KNOT), 0.0, 1.0)
	turn_rate = rudder_angle() / 35.0 * data.max_turn_rate * flow * signf(speed)
	heading = fposmod(heading + turn_rate * dt, 360.0)
	pos += direction() * speed * dt

	var before := depth
	var dive_rate := data.max_dive_rate * lerpf(0.35, 1.0, flow)
	depth = move_toward(depth, maxf(ordered_depth, 0.0), dive_rate * dt)
	# Flooding makes her heavy. Planes and way on hold some of it; past that she sinks.
	var hold := 0.15 + 0.5 * flow
	depth += maxf(0.0, (heaviness - 0.05) * 6.0 - hold) * dt
	var sink_rate := (depth - before) / dt if dt > 0.0 else 0.0
	pitch = lerpf(pitch, clampf(-sink_rate * 9.0, -8.0, 8.0), clampf(dt * 0.8, 0.0, 1.0))


func to_snapshot() -> Dictionary:
	return {
		"p": pos, "h": heading, "s": speed, "d": depth, "od": ordered_depth,
		"tg": telegraph, "r": rudder, "up": periscope_raised, "pi": pitch, "tr": turn_rate, "hv": heaviness,
	}


func apply_snapshot(s: Dictionary) -> void:
	pos = s.p
	heading = s.h
	speed = s.s
	depth = s.d
	ordered_depth = s.od
	telegraph = s.tg
	rudder = s.r
	periscope_raised = s.up
	pitch = s.pi
	turn_rate = s.tr
	heaviness = s.hv
