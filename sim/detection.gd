class_name Detection
## How noticeable the sub is to one ship, as an awareness gain per second. Pure functions so
## the numbers are easy to test and tune. Awareness runs 0..1 and decays when nothing is
## noticed (see ShipAI).

const VISUAL_RATE := 0.012
const HEARING_RATE := 0.04
const SURFACED_EXPOSURE := 6.0

## The patrol's conditions; OceanWorld sets this before stepping its ships.
static var conditions := Conditions.new()
static var sharpness := 1.0 ## the realism level: lookouts and hydrophones pick the boat up this much faster


## Sound the sub makes, 0.1 (creeping) .. ~1.6 (flank on the surface, both diesels).
static func sub_noise(sub: SubState) -> float:
	var frac := absf(sub.speed) / (sub.data.submerged_speed_kn * SubState.KNOT)
	var noise := 0.1 + 0.9 * frac * frac
	if sub.is_surfaced():
		noise = 0.6 + 0.7 * minf(frac, 1.0) + 0.15 * sub.diesels_running()
	elif sub.depth < 20.0 and frac > 0.5:
		noise *= 1.3 # shallow screws cavitate
	return noise


## How visible the sub is: 0 when deep with the scope down.
static func sub_exposure(sub: SubState) -> float:
	if sub.is_surfaced():
		return SURFACED_EXPOSURE
	var h := sub.scope_height()
	if h <= 0.0:
		return 0.0
	var kn := absf(sub.speed) / SubState.KNOT
	return clampf(h / 3.0, 0.3, 1.0) * (1.0 + kn / 3.0) # feather grows with speed


## A ship's own speed drowns out its hydrophones.
static func hearing_factor(ship: ShipState) -> float:
	var kn := ship.speed / SubState.KNOT
	return clampf(1.0 - (kn - 14.0) / 10.0, 0.1, 1.0)


static func awareness_gain(ship: ShipState, sub: SubState) -> float:
	var d := ship.pos.distance_to(sub.pos)
	var gain := 0.0
	var see_range := ship.data.lookout_range * (2.0 if sub.is_surfaced() else 1.0) * conditions.visual_factor()
	if d < see_range:
		var f := 1.0 - d / see_range
		gain += VISUAL_RATE * sub_exposure(sub) * f * f
	if ship.data.hydrophone_range > 0.0 and d < ship.data.hydrophone_range:
		var f := 1.0 - d / ship.data.hydrophone_range
		gain += HEARING_RATE * sub_noise(sub) * f * f * hearing_factor(ship) * conditions.hearing_factor(sub.depth)
	return gain * sharpness


## Chance that one active-sonar ping returns an echo from the sub.
static func ping_chance(ship: ShipState, sub: SubState) -> float:
	if ship.data.sonar_range <= 0.0 or sub.is_surfaced():
		return 0.0
	var d := ship.pos.distance_to(sub.pos)
	if d > ship.data.sonar_range or d < 120.0: # the sub slips under the beam up close
		return 0.0
	var depth_f := lerpf(1.0, 0.55, clampf(sub.depth / 150.0, 0.0, 1.0))
	return conditions.sonar_factor(sub.depth) * clampf((1.0 - d / ship.data.sonar_range) * 1.2, 0.0, 0.9) * depth_f * hearing_factor(ship)
