class_name Torpedo
extends RefCounted
## A Mk 14 torpedo running straight on its gyro course.

const SPEED := 46.0 * SubState.KNOT
const MAX_RANGE := 4000.0

var id := 0
var pos := Vector2.ZERO
var heading := 0.0
var run := 0.0 ## metres travelled
var dud := false ## rolled at launch; a dud hits but does not explode
var alive := true
var spotted := false ## a lookout has seen its bubble track (once is enough)


## Where it was fired from: the far end of its track.
func origin() -> Vector2:
	return pos - direction() * run


func direction() -> Vector2:
	var rad := deg_to_rad(heading)
	return Vector2(sin(rad), cos(rad))


func step(dt: float) -> void:
	var d := SPEED * dt
	pos += direction() * d
	run += d
	if run >= MAX_RANGE:
		alive = false


func to_snapshot() -> Dictionary:
	return {"id": id, "p": pos, "h": heading}
