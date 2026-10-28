class_name DepthCharge
extends RefCounted
## A Type 95 depth charge: sinks at a fixed rate and goes off at its set depth.

const SINK_RATE := 2.6 ## m/s
const LETHAL := 8.0
const HEAVY := 20.0
const LIGHT := 40.0
const SHAKE := 90.0

var pos := Vector2.ZERO
var depth := 0.0
var set_depth := 30.0


func step(dt: float) -> bool:
	depth += SINK_RATE * dt
	return depth >= set_depth


func to_snapshot() -> Array:
	return [pos, depth]
