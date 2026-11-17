class_name Raft
extends RefCounted
## An inflatable life raft (Blaney: "a yellow rubber WWII-style raft"), launched from the locker
## on deck to get the crew to land. Four seats: the driver at the stern by the outboard (seat 0)
## and three paddlers. Paddled it is slow; with the rocket out of its compartment and fitted to
## the stern it goes up to 250 mph, skipping off the sea, and the driver steers it by hand like
## a small motor boat. Run into a beach or a rock at speed and it bounces, skids up the sand
## and stops, everyone fine (Blaney). Pure simulation: the host steps it, clients coast it.

const SEATS := 4
const PADDLE := 0.55 ## m/s each paddler adds
const PADDLE_TURN := 22.0 ## deg/s the driver turns her, paddling
const ROCKET_TOP := 111.8 ## m/s: 250 mph
const ROCKET_PUSH := 16.0 ## m/s² flat out
const ROCKET_TURN := 38.0 ## deg/s at the tiller, under way; less flat out
const DRAG := 0.6 ## per second, the water slowing her (a rubber boat stops quick)
const SKIP_FROM := 22.0 ## m/s: faster than this she starts skipping off the waves
const GRAVITY := 9.8
const LAND := 0.4 ## m of water under her below which she touches bottom
const SAND_GRIP := 9.0 ## m/s² the sand slows her once she's up the beach
const STEEP := 6.0 ## m above the water: she won't skid further up than this

var id := 0
var pos := Vector2.ZERO ## m, x east, y north
var heading := 0.0 ## deg, 0 north, clockwise
var speed := 0.0 ## m/s along her heading (negative: backing)
var hop := 0.0 ## m she is in the air off the water (skipping, or bouncing up a beach)
var vy := 0.0 ## m/s up
var rocket := false ## the rocket out of its compartment and fitted on the stern
var throttle := 0.0 ## -1..1 the rocket's throttle (driver)
var steer := 0.0 ## -1..1 the tiller (driver)
var paddles: Array[float] = [0.0, 0.0, 0.0, 0.0] ## each seat's paddling, -1..1
var crew: Array[int] = [0, 0, 0, 0] ## peer id in each seat, 0 empty
var ground := 0.0 ## m: how high the ground under her is (0 afloat; up the beach, the sand's height)
var skips := 0 ## times she has come down off a skip (for the slap and the tests)
var bumps := 0 ## times she has hit the shore hard
var empty_for := 0.0 ## s nobody has been in her (the host hauls her in alongside the boat)


func seat_of(peer: int) -> int:
	return crew.find(peer)


func free_seat() -> int:
	return crew.find(0)


func is_empty() -> bool:
	for c in crew:
		if c != 0:
			return false
	return true


func beached() -> bool:
	return ground > -LAND and absf(speed) < 0.3 and hop <= 0.0


func direction() -> Vector2:
	var h := deg_to_rad(heading)
	return Vector2(sin(h), cos(h))


## One step. `seabed` is the floor (null in some tests: open sea); `rng` the host's dice (null on
## a client, which only coasts her between snapshots).
func step(dt: float, seabed: Seabed, rng: RandomNumberGenerator) -> void:
	var afloat := hop <= 0.0 and ground <= -LAND
	if rng == null: # a client: she just coasts on between the host's snapshots
		pos += direction() * speed * dt
		if hop > 0.0:
			vy -= GRAVITY * dt
			hop = maxf(hop + vy * dt, 0.0)
		return
	# Power: the rocket (afloat or in the air, it doesn't care), else the paddles (afloat only).
	var push := 0.0
	if rocket:
		push = ROCKET_PUSH * throttle
	elif afloat:
		var want := 0.0
		for i in SEATS:
			if crew[i] != 0:
				want += paddles[i] * PADDLE
		push = (want - speed) * 1.5 # paddlers keep her at the speed they make, no faster
	speed += push * dt
	if afloat or hop > 0.0:
		speed -= speed * DRAG * dt * (0.2 if hop > 0.0 else (0.08 if rocket and throttle > 0.0 else 1.0))
	if rocket:
		speed = clampf(speed, -8.0, ROCKET_TOP)
	# Steering: by hand on the tiller (driver), only with water under her.
	if hop <= 0.0 and ground <= -LAND:
		var rate := PADDLE_TURN if not rocket else ROCKET_TURN * lerpf(1.0, 0.45, clampf(absf(speed) / ROCKET_TOP, 0.0, 1.0))
		heading = fposmod(heading + steer * rate * dt * (signf(speed) if absf(speed) > 0.5 else 1.0), 360.0)
	# Where she goes, and what's under her there.
	var next := pos + direction() * speed * dt
	var floor_next := seabed.floor_depth(next) if seabed != null else 600.0
	var height_next := -floor_next # the ground's height there (+ above water)
	if height_next > -LAND:
		if height_next > STEEP and speed > 0.0:
			# Too steep or a rock face: she stops dead and bounces back a little.
			if absf(speed) > 3.0:
				bumps += 1
				vy = maxf(vy, minf(absf(speed) * 0.08, 6.0))
				hop = maxf(hop, 0.01)
			speed = -speed * 0.15
			next = pos
			floor_next = seabed.floor_depth(pos) if seabed != null else 600.0
		elif ground <= -LAND and absf(speed) > 3.0:
			# Running up onto the sand fast: a bounce, then a skid.
			bumps += 1
			vy = maxf(vy, minf(absf(speed) * 0.06, 7.0))
			hop = maxf(hop, 0.01)
			speed *= 0.7
	pos = next
	ground = maxf(-floor_next, -LAND - 0.01) if floor_next < LAND else -LAND - 0.01
	if hop <= 0.0 and ground > -LAND:
		# On the sand: it grips her; she slides on, slower and slower, then stops.
		speed = move_toward(speed, 0.0, SAND_GRIP * dt)
		if rocket and throttle > 0.0 and speed < 0.0:
			speed = 0.0
	# Skipping: flat out she leaps off the wave tops, and slaps down again (Blaney: "fun feeling
	# physics with the boat skipping").
	if hop <= 0.0 and afloat and speed > SKIP_FROM and rng != null:
		var chance := clampf((speed - SKIP_FROM) / 40.0, 0.0, 1.0) * 1.6 * dt
		if rng.randf() < chance:
			vy = speed * rng.randf_range(0.03, 0.075)
			hop = 0.01
	if hop > 0.0 or vy > 0.0:
		vy -= GRAVITY * dt
		hop += vy * dt
		if hop <= 0.0:
			hop = 0.0
			if vy < -2.0:
				skips += 1
				speed *= 0.97
			vy = 0.0
	if is_empty():
		empty_for += dt
	else:
		empty_for = 0.0


## Her height above the still sea: the sand under her, and in the air when skipping.
func height() -> float:
	return maxf(ground, 0.0) + hop


func to_snapshot() -> Array:
	return [id, pos, heading, speed, hop, vy, rocket, throttle, steer, crew.duplicate(), ground]


func apply_snapshot(a: Array) -> void:
	id = a[0]
	pos = a[1]
	heading = a[2]
	speed = a[3]
	hop = a[4]
	vy = a[5]
	rocket = a[6]
	throttle = a[7]
	steer = a[8]
	var c: Array = a[9]
	for i in SEATS:
		crew[i] = int(c[i]) if i < c.size() else 0
	ground = a[10]
