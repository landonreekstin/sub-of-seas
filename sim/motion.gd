class_name SubMotion
## How the boat moves under her crew: the swell's roll, pitch, yaw and heave (strong on the
## surface, fading with depth to a slow drift that never quite stops), heel in a turn, trim
## from diving and from way on her. Pure, from replicated state, so the interior view, the
## deck and the outside cameras all agree on every machine.

const RESIDUAL_ROLL := 0.2 ## degrees: deep and stopped she still drifts a little
const RESIDUAL_PITCH := 0.1
const DECAY := 12.0 ## metres: the swell's motion falls off by e every this far down
const KNOT := 0.514444


## Roll amplitude in degrees on the surface for a sea (0 calm .. 2 rough, 2.5 in a squall):
## about 1° calm, 3.5° moderate, 7° rough (Blaney: strong but playable).
static func swell(sea: float) -> float:
	return 1.2 + 2.3 * sea + 1.2 * maxf(sea - 1.0, 0.0)


## How much of the swell reaches the boat at this keel depth: all of it surfaced, a third at
## periscope depth, next to nothing below 50 m.
static func depth_factor(depth: float) -> float:
	return exp(-maxf(depth - SubState.AWASH_DEPTH, 0.0) / DECAY)


## The boat's attitude in degrees, in her own frame: x pitch (bow up +), y yaw (to port +),
## z roll (starboard up +).
static func attitude(sub: SubState, sea: float, t: float) -> Vector3:
	var f := depth_factor(sub.depth)
	var flow := clampf(absf(sub.speed) / (4.0 * KNOT), 0.0, 1.0)
	var amp := swell(sea) * f
	var roll_amp := amp * (1.0 - 0.2 * flow) # way on steadies her
	var pitch_amp := amp * 0.45 * (1.0 + 0.5 * flow) # and drives her into the seas
	var roll := roll_amp * (0.75 * sin(TAU * t / 8.5) + 0.35 * sin(TAU * t / 13.7 + 1.7))
	roll += RESIDUAL_ROLL * sin(TAU * t / 23.0 + 0.4)
	roll += clampf(sub.turn_rate * 1.2, -4.0, 4.0) # heel in a turn
	var pitch := pitch_amp * (0.7 * sin(TAU * t / 6.3 + 0.9) + 0.4 * sin(TAU * t / 9.1 + 2.6))
	pitch += RESIDUAL_PITCH * sin(TAU * t / 17.0 + 1.1)
	pitch += sub.pitch + 0.4 * flow * f # dive angle, and her bow lifting with way on
	var yaw := amp * 0.3 * sin(TAU * t / 11.0 + 2.1)
	return Vector3(pitch, yaw, roll)


## Heave in metres: how far the swell lifts and drops her.
static func heave(sub: SubState, sea: float, t: float) -> float:
	var f := depth_factor(sub.depth)
	return 0.12 * (1.0 + 1.6 * sea) * f * (0.8 * sin(TAU * t / 7.3 + 0.8) + 0.3 * sin(TAU * t / 4.9 + 2.2))


## Her attitude as a rotation of the boat's frame (bow -z, starboard +x).
static func basis(att: Vector3) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(att.y)) * Basis(Vector3.RIGHT, deg_to_rad(att.x)) * Basis(Vector3.BACK, deg_to_rad(att.z))
