class_name Seabed
extends RefCounted
## The sea floor and the land: islands ringed by reefs, seamounts and wide shelves rising out
## of the deep ocean floor. floor_depth() is metres below the surface (negative is land above
## it). The host generates it for the patrol, clear of the boat and the ships' tracks, and
## sends the features to the clients once (crew state); everything else derives from them.

const BASE := 600.0 ## open-ocean floor, far below any boat's crush depth
const KINDS: Array[String] = ["island", "seamount", "shelf"]

## Each: {kind, x, y, r (m), top (m: island height above water as a negative, or the depth of
## a seamount's peak / a shelf's flat), reef (island: depth of its reef flat), ang (rad),
## stretch, h (coastline harmonics: [amp, phase] for k = 2..5)}
var features: Array[Dictionary] = []
var version := 0 ## goes up whenever the features change, so views know to rebuild


## Metres from the surface down to the floor at `p`; negative is dry land that high.
func floor_depth(p: Vector2) -> float:
	var depth := BASE
	for f: Dictionary in features:
		var d := _norm_dist(f, p)
		if d >= 2.0:
			continue
		depth = minf(depth, _profile(f, d))
	return depth


func is_land(p: Vector2) -> bool:
	return floor_depth(p) < 0.0


## A course clear of anything shallower than `draft` for `look` metres ahead: `course` itself
## if it is clear, else the nearest one either side that is (or `course` if none is).
func clear_course(pos: Vector2, course: float, draft: float, look: float) -> float:
	for off in [0.0, 20.0, -20.0, 40.0, -40.0, 60.0, -60.0, 90.0, -90.0, 120.0, -120.0, 150.0, -150.0]:
		var c := fposmod(course + off, 360.0)
		if _clear(pos, c, draft, look):
			return c
	return course


func _clear(pos: Vector2, course: float, draft: float, look: float) -> bool:
	var dir := Vector2(sin(deg_to_rad(course)), cos(deg_to_rad(course)))
	var step := look / 5.0
	for i in range(1, 6):
		if floor_depth(pos + dir * step * i) < draft:
			return false
	return true


## Distance from `p` scaled by the feature's own shape: < 1 inside its footprint.
func _norm_dist(f: Dictionary, p: Vector2) -> float:
	var rel := (p - Vector2(f.x, f.y)).rotated(-float(f.ang))
	rel.x /= float(f.stretch)
	var theta := atan2(rel.y, rel.x)
	var shape := 1.0
	var harm: Array = f.h
	for k in harm.size():
		shape += float(harm[k][0]) * sin((k + 2) * theta + float(harm[k][1]))
	return rel.length() / (float(f.r) * shape)


func _profile(f: Dictionary, d: float) -> float:
	var top := float(f.top)
	match f.kind:
		"island": # land to the coast at 0.55, a reef flat out to 1, then the drop-off
			if d < 0.55:
				return top * (1.0 - smoothstep(0.0, 0.55, d)) - 0.5
			if d < 1.0:
				return lerpf(1.0, float(f.reef), smoothstep(0.55, 0.8, d))
			return lerpf(float(f.reef), BASE, smoothstep(1.0, 2.0, d))
		"seamount": # a rounded peak
			return lerpf(top, BASE, smoothstep(0.15, 1.6, d))
		_: # shelf: a wide flat at `top`, then a slope down
			return lerpf(top, BASE, smoothstep(0.85, 1.6, d))


## Lays out a patrol's sea floor around `centre`. Nothing comes within `clear` metres of the
## `keep_clear` points or of the `routes` ([from, to] segments: where the ships will steam).
func generate(seed_value: int, centre: Vector2, keep_clear: Array[Vector2], routes: Array, clear := 2500.0, islands_only := false) -> void:
	features.clear()
	version += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var want := {"island": rng.randi_range(2, 3), "seamount": rng.randi_range(2, 5), "shelf": rng.randi_range(0, 1)}
	if islands_only:
		want = {"island": rng.randi_range(1, 2), "seamount": 0, "shelf": 0}
	for kind: String in KINDS:
		var placed := 0
		for attempt in 60:
			if placed >= want[kind]:
				break
			var f := _random_feature(rng, kind, centre)
			if _fits(f, keep_clear, routes, clear):
				features.append(f)
				placed += 1


func _random_feature(rng: RandomNumberGenerator, kind: String, centre: Vector2) -> Dictionary:
	var r := 0.0
	var top := 0.0
	var dist := 0.0
	match kind:
		"island":
			r = rng.randf_range(900.0, 2600.0)
			top = -rng.randf_range(50.0, 260.0)
			dist = rng.randf_range(4000.0, 10000.0)
		"seamount":
			r = rng.randf_range(350.0, 900.0)
			top = rng.randf_range(18.0, 70.0)
			dist = rng.randf_range(1500.0, 9000.0)
		_:
			r = rng.randf_range(1800.0, 3500.0)
			top = rng.randf_range(55.0, 90.0)
			dist = rng.randf_range(3000.0, 10000.0)
	var at := centre + Vector2.from_angle(rng.randf() * TAU) * dist
	var harm := []
	for k in 4:
		harm.append([rng.randf_range(0.0, 0.16 / (k + 1)), rng.randf() * TAU])
	return {
		"kind": kind, "x": at.x, "y": at.y, "r": r, "top": top, "reef": rng.randf_range(3.0, 12.0),
		"ang": rng.randf() * TAU, "stretch": rng.randf_range(1.0, 1.8), "h": harm,
	}


## Room for the feature: its whole footprint (out to where the slope reaches the deep floor
## for anything a boat could hit) stays `clear` from the points and routes.
func _fits(f: Dictionary, keep_clear: Array[Vector2], routes: Array, clear: float) -> bool:
	var c := Vector2(f.x, f.y)
	var reach := float(f.r) * float(f.stretch) * 1.4 + clear
	for p in keep_clear:
		if p.distance_to(c) < reach:
			return false
	for seg: Array in routes:
		if Geometry2D.get_closest_point_to_segment(c, seg[0], seg[1]).distance_to(c) < reach:
			return false
	for other: Dictionary in features:
		if Vector2(other.x, other.y).distance_to(c) < (float(other.r) + float(f.r)) * 1.2:
			return false
	return true


func to_array() -> Array:
	return features.duplicate(true)


func from_array(a: Array) -> void:
	features.clear()
	version += 1
	for f: Dictionary in a:
		features.append(f)
