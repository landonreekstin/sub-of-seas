class_name Waves
## The sea's waves where a swimmer or a raft is, worked out the way the ocean shader moves its
## mesh (the five Gerstner waves of world/ocean.gdshader, on the near ocean's 13 m grid), so a
## head treading water rides the very waves that are drawn (Blaney: "when people swim and hold
## space their heads stay above the waves").

const WAVES := [ # direction x, z, steepness, wavelength (m): as in ocean.gdshader
	[1.0, 0.35, 0.20, 46.0], [0.6, -0.8, 0.16, 23.0], [-0.3, 1.0, 0.12, 11.0],
	[0.9, 0.6, 0.08, 6.3], [-0.7, -0.4, 0.06, 3.7]]
const ROLLOVER := 3600.0 ## s: the shader's TIME wraps here (Godot's default)

static var amplitude := 0.5 ## the shader's amplitude, set with the sea state (ExteriorWorld)
static var grid_origin := Vector2.ZERO ## where the near ocean's mesh sits (x, z), set by ExteriorWorld
static var cell := 4000.0 / 301.0 ## m between the near ocean's vertices (300 cuts: 301 cells)
static var still := false ## dived: the surface is far over the boat, nobody rides it


## The shader's clock.
static func now() -> float:
	return fmod(Time.get_ticks_msec() / 1000.0, ROLLOVER)


## How high the sea is over its still level at exterior (x, z), as drawn: the waves at the
## mesh's corners round the point, blended.
static func height(x: float, z: float, t := -1.0) -> float:
	if still:
		return 0.0
	if t < 0.0:
		t = now()
	var lx := (x - grid_origin.x + 2000.0) / cell
	var lz := (z - grid_origin.y + 2000.0) / cell
	var i := floorf(lx)
	var j := floorf(lz)
	var fx := lx - i
	var fz := lz - j
	var x0 := grid_origin.x - 2000.0 + i * cell
	var z0 := grid_origin.y - 2000.0 + j * cell
	var a := raw(x0, z0, t)
	var b := raw(x0 + cell, z0, t)
	var c := raw(x0, z0 + cell, t)
	var d := raw(x0 + cell, z0 + cell, t)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


## The waves' height at a vertex at exterior (x, z).
static func raw(x: float, z: float, t: float) -> float:
	var y := 0.0
	for w: Array in WAVES:
		var steep: float = float(w[2]) * amplitude
		var k: float = TAU / float(w[3])
		var c := sqrt(9.8 / k)
		var d := Vector2(w[0], w[1]).normalized()
		var f := k * (d.dot(Vector2(x, z)) - c * t)
		y += steep / k * sin(f)
	return y
