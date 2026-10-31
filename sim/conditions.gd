class_name Conditions
extends RefCounted
## Weather, light and water for a patrol: night, sea state, the thermocline and rain squalls.
## They change what the enemy can see and hear (Detection reads them) and how the sea and the
## boat look.
##
## Squalls (lando: "rain and squalls that roll across the patrol"): round patches of heavy rain
## a couple of km across that drift with the wind, build up, and blow through in a quarter of an
## hour. Inside one, lookouts (ours and theirs) see a fraction as far and the sea runs higher, so
## a boat can use one as cover to close in. The host makes and ends them; every peer drifts them.

const SEA_NAMES := ["calm", "moderate", "rough"]
const RAIN_SIGHT := 0.25 ## how far a lookout sees through the heart of a squall, as a fraction
const RAIN_HEARING := 0.8 ## rain drumming on the sea dulls hydrophones this much
const SQUALL_SPAWN := 9000.0 ## new squalls form this far upwind of the boat (out of sight)
const SQUALL_FORGET := 22000.0 ## and are dropped this far off
const SQUALL_BUILD := 120.0 ## seconds to build up to full rain, and to die away
const SQUALLS_BY_SEA := [1, 2, 3] ## how many the patrol keeps about, by sea state

var night := false
var sea_state := 1 ## 0 calm, 1 moderate, 2 rough
var layer_depth := 0.0 ## depth of the thermocline in metres; 0 = none
var squall_count := 0 ## squalls the host keeps about; 0 = clear weather
var wind := 0.0 ## the way the squalls drift, degrees true (toward)
## Each: [x, y, radius, age, life] in metres and seconds. They drift with `wind`.
var squalls: Array = []


## Lookouts: night cuts their range hard; rough water hides a periscope's feather.
func visual_factor() -> float:
	return (0.3 if night else 1.0) * [1.2, 1.0, 0.65][sea_state]


## The same between two points: rain at either end, or between them, hides a lot.
func visual_between(a: Vector2, b: Vector2) -> float:
	return visual_factor() * lerpf(1.0, RAIN_SIGHT, rain_between(a, b))


## Hydrophones: rough seas drown things out.
func hearing_factor(sub_depth: float) -> float:
	return [1.1, 1.0, 0.7][sea_state] * (0.55 if below_layer(sub_depth) else 1.0)


## The same for a ship listening at `at`: rain on the sea round her is noise too.
func hearing_at(at: Vector2, sub_depth: float) -> float:
	return hearing_factor(sub_depth) * lerpf(1.0, RAIN_HEARING, rain_at(at))


## Active sonar bounces off the layer: a boat under it is hard to find.
func sonar_factor(sub_depth: float) -> float:
	return 0.4 if below_layer(sub_depth) else 1.0


func below_layer(sub_depth: float) -> bool:
	return layer_depth > 0.0 and sub_depth > layer_depth + 3.0


## How hard it is raining at `p`, 0 (dry) .. 1 (the heart of a squall).
func rain_at(p: Vector2) -> float:
	var r := 0.0
	for s: Array in squalls:
		var d := p.distance_to(Vector2(s[0], s[1]))
		var radius: float = s[2]
		if d < radius:
			r = maxf(r, squall_strength(s) * smoothstep(radius, radius * 0.55, d))
	return r


func rain_between(a: Vector2, b: Vector2) -> float:
	if squalls.is_empty():
		return 0.0
	return maxf(maxf(rain_at(a), rain_at(b)), rain_at((a + b) * 0.5))


## The sea state at `p`: a squall brings its own wind and a sea a step rougher.
func sea_at(p: Vector2) -> float:
	return minf(float(sea_state) + rain_at(p), 2.5)


## 0..1: a squall builds up, rains, and dies away.
static func squall_strength(s: Array) -> float:
	var age: float = s[3]
	var life: float = s[4]
	return clampf(minf(age, life - age) / SQUALL_BUILD, 0.0, 1.0)


func wind_dir() -> Vector2:
	var rad := deg_to_rad(wind)
	return Vector2(sin(rad), cos(rad))


## Drifts the squalls on every peer; on the host (`rng` given) also ends old ones and brings
## new ones in upwind of `around` (the boat) to keep `squall_count` about.
func step(dt: float, around: Vector2, rng: RandomNumberGenerator = null) -> void:
	var drift := wind_dir() * (4.0 + sea_state * 2.0) * dt
	for s: Array in squalls:
		s[0] += drift.x
		s[1] += drift.y
		s[3] += dt
	if rng == null:
		return
	squalls = squalls.filter(func(s: Array) -> bool:
		return s[3] < s[4] and around.distance_to(Vector2(s[0], s[1])) < SQUALL_FORGET)
	while squalls.size() < squall_count:
		add_squall(around - wind_dir() * SQUALL_SPAWN + wind_dir().orthogonal() * rng.randf_range(-6000.0, 6000.0), rng)


## A squall at `p`, just starting to build. `age` puts it further along (patrols start with
## some already raining).
func add_squall(p: Vector2, rng: RandomNumberGenerator, age := 0.0) -> Array:
	var s := [p.x, p.y, rng.randf_range(1400.0, 2600.0), age, rng.randf_range(900.0, 1500.0)]
	squalls.append(s)
	return s


## A patrol's weather: `count` squalls (-1 = by sea state) on a wind from a random quarter,
## the first ones already about, and out of the boat's way.
func setup_weather(count: int, around: Vector2, rng: RandomNumberGenerator) -> void:
	squall_count = SQUALLS_BY_SEA[sea_state] if count < 0 else count
	wind = rng.randf() * 360.0
	squalls.clear()
	for i in squall_count:
		var at := around + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(4000.0, 12000.0)
		add_squall(at, rng, rng.randf_range(SQUALL_BUILD, 500.0))


func describe() -> String:
	var bits: Array[String] = ["night" if night else "day", "%s sea" % SEA_NAMES[sea_state]]
	bits.append("a layer at %d m" % roundi(layer_depth) if layer_depth > 0.0 else "no layer")
	if squall_count > 0:
		bits.append("rain squalls about" if squall_count > 1 else "a rain squall about")
	return ", ".join(bits)


func to_snapshot() -> Array:
	var sq := []
	for s: Array in squalls:
		sq.append(PackedFloat32Array(s))
	return [night, sea_state, layer_depth, wind, sq]


func apply_snapshot(a: Array) -> void:
	night = a[0]
	sea_state = a[1]
	layer_depth = a[2]
	if a.size() > 4:
		wind = a[3]
		squalls = (a[4] as Array).map(func(p: PackedFloat32Array) -> Array: return Array(p))
