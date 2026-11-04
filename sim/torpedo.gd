class_name Torpedo
extends RefCounted
## A Mk 14 torpedo running straight on its gyro course.

const SPEED := 46.0 * SubState.KNOT ## the real Mk 14; Arcade runs them faster (Realism)
const MAX_RANGE := 4000.0

var id := 0
var pos := Vector2.ZERO
var heading := 0.0
var speed := SPEED ## m/s, from the realism level
var run := 0.0 ## metres travelled
var dud := false ## rolled at launch; a dud hits but does not explode
var alive := true
var enemy := false ## fired at us by an enemy sub
var depth := 0.0 ## the depth it runs at: the firing boat's
var spotted := false ## a lookout has seen its bubble track (once is enough)


## Where it was fired from: the far end of its track.
func origin() -> Vector2:
	return pos - direction() * run


func direction() -> Vector2:
	var rad := deg_to_rad(heading)
	return Vector2(sin(rad), cos(rad))


func step(dt: float) -> void:
	var d := speed * dt
	pos += direction() * d
	run += d
	if run >= MAX_RANGE:
		alive = false


func to_snapshot() -> Dictionary:
	return {"id": id, "p": pos, "h": heading}
