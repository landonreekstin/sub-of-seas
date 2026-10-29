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
const HOTEL_LOAD := 0.15 ## battery draw stopped (lights, pumps, fans) relative to AHEAD 1/3
const DIESEL_START_TIME := 5.0 ## seconds of cranking before a diesel runs
const DIESEL_SPEED := [0.0, 0.7, 1.0] ## fraction of surface speed with 0, 1, 2 diesels running
const INDUCTION_DEPTH := 3.0 ## diesels flood if she goes deeper than this with them on

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
var battery := 1.0 ## charge 0..1
var diesels: Array[float] = [0.0, 0.0] ## per engine: 0 stopped, 0..1 cranking, 1 running
var charge_rate := 0.0 ## battery change per second last step, for gauges (+ charging)


func _init(sub_class: SubClassData) -> void:
	data = sub_class


func is_surfaced() -> bool:
	return depth < 1.0


func diesels_running() -> int:
	return diesels.filter(func(d: float) -> bool: return d >= 1.0).size()


## Diesels drive her on the surface; otherwise the motors run off the battery.
func max_speed() -> float:
	if is_surfaced() and diesels_running() > 0:
		return data.surface_speed_kn * DIESEL_SPEED[diesels_running()] * KNOT
	if battery <= 0.0:
		return 0.0
	return data.submerged_speed_kn * KNOT


## Battery draw per second on the motors at `spd` m/s: AHEAD 1/3 lasts the class's
## endurance; power rises steeply with speed (^1.5, gentler than real life so a sprint
## is costly but possible): flank empties it ~7x faster, in ~4 min on a Gato.
func battery_drain(spd: float) -> float:
	var slow: float = data.submerged_speed_kn * KNOT * TELEGRAPH[1]
	var load := HOTEL_LOAD + (1.0 - HOTEL_LOAD) * pow(spd / slow, 1.5)
	return load / (data.battery_endurance_min * 60.0)


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
	_step_power(dt)
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


func _step_power(dt: float) -> void:
	for i in diesels.size():
		if diesels[i] > 0.0 and diesels[i] < 1.0:
			diesels[i] = minf(1.0, diesels[i] + dt / DIESEL_START_TIME)
	var running := diesels_running()
	if is_surfaced() and running > 0:
		# What the screws don't take goes into the battery.
		var load := absf(speed) / (data.surface_speed_kn * KNOT)
		charge_rate = running * (1.0 - 0.8 * load) / (2.0 * data.charge_minutes * 60.0)
	else:
		charge_rate = -battery_drain(absf(speed))
	battery = clampf(battery + charge_rate * dt, 0.0, 1.0)


func to_snapshot() -> Dictionary:
	return {
		"p": pos, "h": heading, "s": speed, "d": depth, "od": ordered_depth,
		"tg": telegraph, "r": rudder, "up": periscope_raised, "pi": pitch, "tr": turn_rate, "hv": heaviness,
		"bt": battery, "dz": diesels, "cr": charge_rate,
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
	battery = s.bt
	diesels.assign(s.dz)
	charge_rate = s.cr
