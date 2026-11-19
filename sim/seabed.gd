class_name Seabed
extends RefCounted
## The sea floor and the land: islands ringed by reefs, seamounts and wide shelves rising out
## of the deep ocean floor. floor_depth() is metres below the surface (negative is land above
## it). The host generates it for the patrol, clear of the boat and the ships' tracks, and
## sends the features to the clients once (crew state); everything else derives from them.

const BASE := 600.0 ## open-ocean floor, far below any boat's crush depth
const KINDS: Array[String] = ["island", "seamount", "shelf", "trench"]
## A cave (Blaney: "a short underwater cave to go through and out the other end"): an S-bend
## tunnel through a rock ridge that stands above the water, so the only way on is through it.
## Its own fields: len (tunnel, m), w (width), bend (the S's sideways swing), roof (shallowest
## roof, m), open (roof to floor), ridge (half the ridge's width across), land (its height
## above water, negative), foot (the floor at its cliffs).
const CAVE_ROOF_SWING := 12.0 ## the roof rises and dips this much along the tunnel
const CAVE_FLOOR_BUMPS := 6.0 ## and the floor comes up this much in places
## Places on the sea floor to go and see (Blaney: "shipwrecks, ruins, glowing vents and gardens,
## alien civilizations"), each on a rise of its own (or in a pit, deeper than the ocean floor) at
## a depth the boat can reach: the garden shallow and bright, the stranger the deeper, the
## crystal city at her test depth. Fields as any feature, plus type and name.
const SITES: Array[String] = ["garden", "wreck", "ruins", "vents", "alien"]
const SITE_DEPTH := {"garden": 0.35, "wreck": 0.6, "ruins": 0.75, "vents": 0.9, "alien": 1.0} ## of her test depth
const SITE_NAMES := {"garden": "the glowing garden", "wreck": "the wreck of the Kiyo Maru", "ruins": "the drowned temple",
	"vents": "the black smokers", "alien": "the crystal city"}
const SITE_R := 280.0 ## m: the flat a site stands on

## Each: {kind, x, y, r (m), top (m: island height above water as a negative, or the depth of
## a seamount's peak / a shelf's flat), reef (island: depth of its reef flat), ang (rad),
## stretch, h (coastline harmonics: [amp, phase] for k = 2..5)}
var features: Array[Dictionary] = []
var version := 0 ## goes up whenever the features change, so views know to rebuild


## Metres from the surface down to the floor at `p`; negative is dry land that high. Inside a
## cave it is the tunnel's floor (its roof is roof_depth); `solid` treats a cave's ridge as all
## rock instead, for drawing the floor around it.
func floor_depth(p: Vector2, solid := false) -> float:
	var depth := BASE
	for f: Dictionary in features: # trenches first: they only ever deepen the open floor
		if f.kind == "trench" or _pit(f):
			var d := _norm_dist(f, p)
			var flat := 0.85 if f.kind == "site" else 0.2 # a site's pit has a wide flat floor
			if d < flat + 1.0:
				depth = maxf(depth, lerpf(float(f.top), BASE, smoothstep(flat, flat + 1.0, d)))
	for f: Dictionary in features:
		if f.kind == "trench" or _pit(f):
			continue
		if f.kind == "cave":
			depth = minf(depth, _cave_floor(f, p, solid))
			continue
		var d := _norm_dist(f, p)
		if d >= 2.0:
			continue
		depth = minf(depth, _profile(f, d))
	return depth


## A site deeper than the ocean floor sits in a pit of its own, like a short trench.
static func _pit(f: Dictionary) -> bool:
	return f.kind == "site" and float(f.top) > BASE - 50.0


## Lays out the sea-floor sites, one of each, 3-14 km from `centre`, clear of the ships' tracks,
## at depths for a boat with this test depth.
func add_sites(seed_value: int, centre: Vector2, test_depth: float, keep_clear: Array[Vector2], routes: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var start := rng.randf() * TAU
	for k in SITES.size():
		var type := SITES[k]
		for attempt in 60:
			var ang := start + TAU * k / SITES.size() + rng.randf_range(-0.5, 0.5)
			var at := centre + Vector2.from_angle(ang) * rng.randf_range(3000.0, 9000.0 + 1000.0 * k)
			var f := {"kind": "site", "type": type, "name": SITE_NAMES[type], "x": at.x, "y": at.y, "r": SITE_R,
				"top": maxf(25.0, test_depth * float(SITE_DEPTH[type])), "reef": 0.0, "ang": rng.randf() * TAU, "stretch": 1.0, "h": []}
			if _fits(f, keep_clear, routes, 600.0) or attempt == 59:
				features.append(f)
				break
	version += 1


## The sites, in SITES order.
func sites() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in features:
		if f.kind == "site":
			out.append(f)
	return out


## How far down a cave's roof is over `p`; 0 is open water above.
func roof_depth(p: Vector2) -> float:
	for f: Dictionary in features:
		if f.kind == "cave":
			var c := cave_local(f, p)
			if in_tunnel(f, c):
				return cave_roof(f, c.x)
	return 0.0


## The cave whose ridge is within `margin` m of `p` (its index), or -1.
func cave_near(p: Vector2, margin := 400.0) -> int:
	for i in features.size():
		var f := features[i]
		if f.kind == "cave":
			var c := cave_local(f, p)
			if absf(c.x) < float(f.len) * 0.5 + margin and absf(c.y) < float(f.ridge) + margin:
				return i
	return -1


## `p` in a cave's own frame: x along the tunnel (the way in at -len/2, out at +len/2), y across.
static func cave_local(f: Dictionary, p: Vector2) -> Vector2:
	return (p - Vector2(f.x, f.y)).rotated(-float(f.ang))


static func cave_world(f: Dictionary, c: Vector2) -> Vector2:
	return Vector2(f.x, f.y) + c.rotated(float(f.ang))


## The tunnel's middle line, sideways from the cave's axis, `u` metres along.
static func cave_centre(f: Dictionary, u: float) -> float:
	return float(f.bend) * sin(TAU * u / float(f.len))


static func cave_roof(f: Dictionary, u: float) -> float:
	return float(f.roof) + CAVE_ROOF_SWING * (0.5 + 0.5 * sin(3.0 * PI * u / float(f.len) + 1.0))


static func cave_bottom(f: Dictionary, u: float) -> float:
	return cave_roof(f, u) + float(f.open) - CAVE_FLOOR_BUMPS * maxf(0.0, sin(5.0 * PI * u / float(f.len) + 0.4))


static func in_tunnel(f: Dictionary, c: Vector2) -> bool:
	return absf(c.x) <= float(f.len) * 0.5 and absf(c.y - cave_centre(f, c.x)) <= float(f.w) * 0.5


func _cave_floor(f: Dictionary, p: Vector2, solid: bool) -> float:
	var c := cave_local(f, p)
	var out := maxf(absf(c.x) - float(f.len) * 0.5, absf(c.y) - float(f.ridge))
	if out > 0.0: # off the ridge: the floor at its cliffs, then down to the deep
		return lerpf(float(f.foot), BASE, smoothstep(250.0, 1800.0, out))
	if solid:
		return float(f.foot)
	if in_tunnel(f, c):
		return cave_bottom(f, c.x)
	return float(f.land)


## A cave sized for a boat (length, beam, keel to the top of her fin, in m; her test depth): wide
## and tall enough for her with room to spare, but only if the crew hold her straight and level.
static func cave_size(length: float, beam: float, height: float, test_depth: float) -> Dictionary:
	var open := height * 1.5 + 22.0
	var roof := clampf(test_depth - CAVE_ROOF_SWING - open - 4.0, 8.0, 24.0)
	return {
		"len": 700.0, "w": clampf(beam * 3.0 + length * 0.12 + 20.0, 24.0, 90.0), "bend": clampf(length * 0.3 + 20.0, 25.0, 60.0),
		"roof": roof, "open": open,
	}


## Puts a cave across the way at `centre`, its tunnel running along `ang` (rad), sized by
## cave_size(); anything else in the way of its ridge is cleared off.
func add_cave(centre: Vector2, ang: float, size: Dictionary, ridge := 1500.0) -> Dictionary:
	var f := {
		"kind": "cave", "x": centre.x, "y": centre.y, "ang": ang, "ridge": ridge, "land": -45.0,
		"foot": float(size.roof) + float(size.open) + 30.0, "r": maxf(ridge, float(size.len)), "stretch": 1.0,
		"top": float(size.roof), "reef": 0.0, "h": [],
	}
	f.merge(size)
	features = features.filter(func(o: Dictionary) -> bool:
		return o.kind == "trench" or Vector2(o.x, o.y).distance_to(centre) > float(o.r) * float(o.stretch) * 1.6 + ridge + 2500.0)
	features.append(f)
	version += 1
	return f


func is_land(p: Vector2) -> bool:
	return floor_depth(p) < 0.0


## A course clear of anything shallower than `draft` for `look` metres ahead: `course` itself
## if it is clear, else the nearest one either side that is (or `course` if none is). `width`
## widens the lane checked to either side, and `step` is how far apart along it (default: five
## looks along the way).
func clear_course(pos: Vector2, course: float, draft: float, look: float, width := 0.0, step := 0.0) -> float:
	for off in [0.0, 20.0, -20.0, 40.0, -40.0, 60.0, -60.0, 90.0, -90.0, 120.0, -120.0, 150.0, -150.0]:
		var c := fposmod(course + off, 360.0)
		if _clear(pos, c, draft, look, width, step):
			return c
	return course


func _clear(pos: Vector2, course: float, draft: float, look: float, width := 0.0, step := 0.0) -> bool:
	var dir := Vector2(sin(deg_to_rad(course)), cos(deg_to_rad(course)))
	var side := Vector2(dir.y, -dir.x)
	var n := 5 if step <= 0.0 else maxi(1, ceili(look / step))
	for i in range(1, n + 1):
		var q := pos + dir * look / n * i
		for off in ([0.0] if width <= 0.0 else [0.0, width, -width]):
			var at: Vector2 = q + side * float(off)
			if floor_depth(at) < draft or roof_depth(at) > 0.0:
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
	# Spread over some 30 km each way (Blaney: a larger area), with a trench or two far below
	# anything a boat survives.
	var want := {"island": rng.randi_range(3, 5), "seamount": rng.randi_range(6, 10), "shelf": rng.randi_range(1, 3), "trench": rng.randi_range(1, 2)}
	if islands_only:
		want = {"island": rng.randi_range(1, 2), "seamount": 0, "shelf": 0, "trench": 0}
	for kind: String in KINDS:
		var placed := 0
		for attempt in 120:
			if placed >= want[kind]:
				break
			var f := _random_feature(rng, kind, centre, placed > 0) # the first island stays near
			if _fits(f, keep_clear, routes, clear):
				features.append(f)
				placed += 1


func _random_feature(rng: RandomNumberGenerator, kind: String, centre: Vector2, placed_any := false) -> Dictionary:
	var r := 0.0
	var top := 0.0
	var dist := 0.0
	match kind:
		"island":
			r = rng.randf_range(900.0, 2600.0)
			top = -rng.randf_range(50.0, 260.0)
			dist = rng.randf_range(4000.0, 30000.0) if placed_any else rng.randf_range(4000.0, 10000.0)
		"seamount":
			r = rng.randf_range(350.0, 900.0)
			top = rng.randf_range(18.0, 70.0)
			dist = rng.randf_range(1500.0, 30000.0)
		"trench": # a long deep valley in the ocean floor
			r = rng.randf_range(3000.0, 6000.0)
			top = rng.randf_range(1400.0, 2600.0)
			dist = rng.randf_range(6000.0, 25000.0)
		_:
			r = rng.randf_range(1800.0, 3500.0)
			top = rng.randf_range(55.0, 90.0)
			dist = rng.randf_range(3000.0, 30000.0)
	var at := centre + Vector2.from_angle(rng.randf() * TAU) * dist
	var harm := []
	for k in 4:
		harm.append([rng.randf_range(0.0, 0.16 / (k + 1)), rng.randf() * TAU])
	return {
		"kind": kind, "x": at.x, "y": at.y, "r": r, "top": top, "reef": rng.randf_range(3.0, 12.0),
		"ang": rng.randf() * TAU, "stretch": rng.randf_range(2.5, 4.0) if kind == "trench" else rng.randf_range(1.0, 1.8), "h": harm,
	}


## Room for the feature: its whole footprint (out to where the slope reaches the deep floor
## for anything a boat could hit) stays `clear` from the points and routes.
func _fits(f: Dictionary, keep_clear: Array[Vector2], routes: Array, clear: float) -> bool:
	var c := Vector2(f.x, f.y)
	if f.kind == "trench": # deep below every keel: it only has to keep off the other features
		for other: Dictionary in features:
			if Vector2(other.x, other.y).distance_to(c) < float(f.r) * float(f.stretch) + float(other.r) * 2.0:
				return false
		return true
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
