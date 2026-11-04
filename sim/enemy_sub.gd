class_name EnemySubAI
extends ShipAI
## An enemy submarine (Blaney's list: a battle with another sub near you). It works its way
## toward where it believes we are, listening; once it hears us well enough it stalks closer and
## fires a pair of straight-running torpedoes down its solution, then turns away, changes depth
## and comes back. Host only, like ShipAI.

const FIRE_RANGE := 3000.0
const RELOAD := 55.0 ## s between salvoes
const LEG := 70.0 ## s on one search leg
const AWARE := 0.3 ## sure enough of us to stalk
const SPREAD := 4.0 ## degrees either side of the solution

var _leg := 0.0
var _reload := 25.0
var _away := 0.0
var _depth_to := 40.0


func _init(s: ShipState) -> void:
	super(s)
	_depth_to = s.depth


func set_depth(d: float) -> void:
	_depth_to = d


func report(_pos: Vector2, _error: float, _rng: RandomNumberGenerator, awareness := 0.6) -> void:
	ship.awareness = maxf(ship.awareness, awareness)


func step(dt: float, world: OceanWorld, rng: RandomNumberGenerator) -> void:
	var sub := world.sub
	ship.awareness = clampf(ship.awareness + (Detection.awareness_gain(ship, sub) - DECAY) * dt, 0.0, 1.0)
	_reload = maxf(_reload - dt, 0.0)
	_away = maxf(_away - dt, 0.0)
	_leg -= dt
	var d := ship.pos.distance_to(sub.pos)
	var hears := ship.awareness > AWARE
	var dodge := _dodge(world)
	if not is_nan(dodge):
		ship.course = dodge
		ship.ordered_speed = ship.data.max_speed_kn * SubState.KNOT
	elif _away > 0.0:
		ship.ordered_speed = ship.data.hunt_speed_kn * SubState.KNOT
	elif hears:
		if ship.mode != Mode.HUNT:
			ship.mode = Mode.HUNT
		_steer(sub.pos, ship.data.hunt_speed_kn if d > FIRE_RANGE * 0.7 else ship.data.search_speed_kn)
		if d < FIRE_RANGE and _reload <= 0.0:
			_fire(world, rng)
	elif _leg <= 0.0:
		# Searching: legs toward somewhere near where we were last thought to be.
		ship.mode = Mode.PATROL
		_leg = LEG
		_steer(sub.pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(600.0, 2500.0), ship.data.search_speed_kn)
	var floor_at := world.seabed.floor_depth(ship.pos)
	ship.depth = move_toward(ship.depth, clampf(_depth_to, 15.0, maxf(floor_at - 15.0, 15.0)), 1.5 * dt)


func _fire(world: OceanWorld, rng: RandomNumberGenerator) -> void:
	_reload = RELOAD / Detection.sharpness
	var sub := world.sub
	var t := Tdc.intercept_time(sub.pos - ship.pos, sub.direction() * sub.speed, world.torpedo_speed * 0.8)
	var at := sub.pos + sub.direction() * sub.speed * maxf(t, 0.0)
	var aim := ShipState.bearing(ship.pos, at) + rng.randf_range(-3.0, 3.0)
	for side in [-1.0, 1.0]:
		world.fire_enemy_torpedo(ship, aim + side * SPREAD)
	# Away from where the torpedoes give him away, and to another depth.
	_away = 30.0
	ship.course = fposmod(aim + 150.0, 360.0)
	_depth_to = rng.randf_range(25.0, 70.0)


## Realistic and sharper: a torpedo heard coming makes him turn beam on to it and run.
func _dodge(world: OceanWorld) -> float:
	if Detection.sharpness <= 1.0:
		return NAN
	for t in world.torpedoes:
		if not t.enemy and t.pos.distance_to(ship.pos) < 1200.0:
			return fposmod(t.heading + 90.0, 360.0)
	return NAN
