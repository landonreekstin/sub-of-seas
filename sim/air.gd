class_name AirState
extends RefCounted
## The air in the boat: CO2 and O2 for the whole boat (percent), smoke per compartment
## (0..1) from fires, the CO2 absorbent canisters and the oxygen bank. Submerged, the crew
## breathe CO2 up and O2 down; surfaced, the hatches are open and it all clears.
## Host-authoritative; replicated in the sim snapshot.

const CO2_FRESH := 0.04
const O2_FRESH := 20.9
const CO2_BASE_PER_MIN := 0.08 ## the boat's own (the crew we don't play) per minute
const CO2_PER_CREW_PER_MIN := 0.04
const O2_PER_CO2 := 0.9 ## O2 used per CO2 made
const SCRUB_PER_MIN := 0.6 ## CO2 a working canister takes out per minute
const CANISTER_SECONDS := 300.0
const BLEED_PER_MIN := 0.8 ## O2 the bleed valve adds per minute
const BANK_MINUTES := 40.0 ## minutes of bleeding a full oxygen bank lasts
const SMOKE_PER_FIRE := 0.02 ## per second at full size: a full fire fouls its room in ~2 min
const SMOKE_FLOW := 0.08 ## per second per unit difference through an open door
const SMOKE_DECAY := 0.002 ## per second, submerged
const VENT_RATE := 0.08 ## per second: how fast fresh air comes in when surfaced
## Air gets bad between these and knocks people out at the top end.
const CO2_BAD := 3.0
const CO2_OUT := 6.0
const O2_BAD := 17.0
const O2_OUT := 14.0
## The boat is lost when the air is this far gone: nobody left awake to surface.
const CO2_LOST := 8.0
const O2_LOST := 12.0

var co2 := CO2_FRESH
var o2 := O2_FRESH
var smoke: Array[float] = []
var canisters := 8
var canister_left := 0.0 ## seconds of scrubbing left in the canister in the scrubber
var bleed := false
var o2_bank := 1.0


func setup(comp_count: int, canisters_aboard: int) -> AirState:
	smoke.resize(comp_count)
	smoke.fill(0.0)
	canisters = canisters_aboard
	return self


## Puts a fresh canister in the scrubber (throwing out the old one). False when none are left.
func load_canister() -> bool:
	if canisters <= 0:
		return false
	canisters -= 1
	canister_left = CANISTER_SECONDS
	return true


func step(dt: float, surfaced: bool, crew_count: int, hull: HullState) -> void:
	if surfaced:
		var k := clampf(VENT_RATE * dt, 0.0, 1.0)
		co2 = lerpf(co2, CO2_FRESH, k)
		o2 = lerpf(o2, O2_FRESH, k)
		for i in smoke.size():
			smoke[i] = lerpf(smoke[i], 0.0, k)
	else:
		var made := (CO2_BASE_PER_MIN + CO2_PER_CREW_PER_MIN * crew_count) / 60.0 * dt
		co2 += made
		o2 -= made * O2_PER_CO2
	if canister_left > 0.0:
		canister_left = maxf(0.0, canister_left - dt)
		co2 = maxf(CO2_FRESH, co2 - SCRUB_PER_MIN / 60.0 * dt)
	if bleed and o2_bank > 0.0:
		o2 = minf(21.5, o2 + BLEED_PER_MIN / 60.0 * dt)
		o2_bank = maxf(0.0, o2_bank - dt / (BANK_MINUTES * 60.0))
	_step_smoke(dt, hull)


func _step_smoke(dt: float, hull: HullState) -> void:
	if smoke.size() != hull.comps.size():
		return
	for f in hull.fires:
		smoke[f.c] = minf(1.0, smoke[f.c] + SMOKE_PER_FIRE * f.size * dt)
		o2 -= 0.05 / 60.0 * f.size * dt # fires burn the boat's oxygen too
	for d: String in hull.links:
		if not hull.doors_open.get(d, false):
			continue
		var a: int = hull.links[d][0]
		var b: int = hull.links[d][1]
		var v := (smoke[a] - smoke[b]) * SMOKE_FLOW * dt
		smoke[a] -= v
		smoke[b] += v
	for i in smoke.size():
		smoke[i] = maxf(0.0, smoke[i] - SMOKE_DECAY * dt)


## How bad the boat-wide air is: 0 fine .. 1 people pass out.
func badness() -> float:
	var from_co2 := inverse_lerp(CO2_BAD, CO2_OUT, co2)
	var from_o2 := inverse_lerp(O2_BAD, O2_OUT, o2)
	return clampf(maxf(from_co2, from_o2), 0.0, 1.0)


## How bad it is to breathe in compartment `c`, counting its smoke.
func badness_in(c: int) -> float:
	var s := smoke[c] if c >= 0 and c < smoke.size() else 0.0
	return clampf(maxf(badness(), inverse_lerp(0.4, 0.9, s)), 0.0, 1.0)


func is_lethal() -> bool:
	return co2 >= CO2_LOST or o2 <= O2_LOST


func to_snapshot() -> Dictionary:
	return {"c": co2, "o": o2, "s": smoke, "n": canisters, "l": canister_left, "b": bleed, "k": o2_bank}


func apply_snapshot(s: Dictionary) -> void:
	co2 = s.c
	o2 = s.o
	smoke.assign(s.s)
	canisters = s.n
	canister_left = s.l
	bleed = s.b
	o2_bank = s.k
