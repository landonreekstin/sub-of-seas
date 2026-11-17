extends RefCounted
## The life rafts: paddling, the rocket to 250 mph, skipping, running up a beach, the snapshot.

const GATO := preload("res://data/subs/gato.tres")

var runner: Object


func _island(dist: float, r := 1000.0) -> Dictionary:
	return {"kind": "island", "x": 0.0, "y": dist, "r": r, "top": -80.0, "reef": 6.0, "ang": 0.0, "stretch": 1.0, "h": []}


func _run(r: Raft, seconds: float, seabed: Seabed = null, rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = 3
	for i in int(seconds * 60.0):
		r.step(1.0 / 60.0, seabed, rng)


func test_paddling_is_slow_and_steady() -> bool:
	var r := Raft.new()
	r.crew = [1, 2, 3, 4] as Array[int]
	r.paddles = [1.0, 1.0, 1.0, 1.0] as Array[float]
	_run(r, 20.0)
	runner.check(r.speed > 1.5 and r.speed < 2.5, "four paddling make about 2 m/s (%.2f)" % r.speed)
	runner.check(r.hop == 0.0 and r.skips == 0, "paddling never skips")
	r.paddles = [0.0, 0.0, 0.0, 0.0] as Array[float]
	_run(r, 8.0)
	runner.check(r.speed < 0.3, "she stops when they stop (%.2f)" % r.speed)
	return true


func test_rocket_to_250_mph_and_skipping() -> bool:
	var r := Raft.new()
	r.crew = [1, 0, 0, 0] as Array[int]
	r.rocket = true
	r.throttle = 1.0
	_run(r, 30.0)
	runner.check(r.speed > 105.0 and r.speed <= Raft.ROCKET_TOP + 0.01, "flat out she does 250 mph (%.0f mph)" % (r.speed * 2.237))
	runner.check(r.skips > 5, "she skips off the waves flat out (%d skips)" % r.skips)
	r.throttle = 0.0
	_run(r, 15.0)
	runner.check(r.speed < 20.0, "throttle off, the sea slows her (%.1f m/s)" % r.speed)
	return true


func test_tiller_turns_her() -> bool:
	var r := Raft.new()
	r.crew = [1, 0, 0, 0] as Array[int]
	r.rocket = true
	r.throttle = 0.5
	r.steer = 1.0
	_run(r, 3.0)
	runner.check(r.heading > 30.0 and r.heading < 180.0, "the tiller swings her to starboard (%.0f°)" % r.heading)
	return true


func test_full_speed_up_the_beach() -> bool:
	var s := Seabed.new()
	s.features.append(_island(3000.0))
	var r := Raft.new()
	r.crew = [1, 0, 0, 0] as Array[int]
	r.rocket = true
	r.throttle = 1.0
	_run(r, 40.0, s)
	runner.check(r.bumps > 0, "she hit the shore hard")
	r.throttle = 0.0
	_run(r, 10.0, s)
	runner.check(r.beached(), "she ends up stopped on the sand (ground %.1f, speed %.2f)" % [r.ground, r.speed])
	runner.check(s.floor_depth(r.pos) < Raft.LAND, "on land, not in the sea (floor %.1f)" % s.floor_depth(r.pos))
	runner.check(r.ground < Raft.STEEP + 1.0, "not up the cliffs (%.1f m)" % r.ground)
	# Paddling back off the beach.
	r.rocket = false
	r.heading = 180.0
	r.paddles = [1.0, 1.0, 1.0, 1.0] as Array[float]
	r.crew = [1, 2, 3, 4] as Array[int]
	return true


func test_launched_alongside_and_in_the_snapshot() -> bool:
	var w := OceanWorld.new(GATO, 7)
	w.hull.setup([{"name": "a", "z0": -10.0, "z1": 0.0}], {}, {"helm": 0})
	var r := w.launch_raft(1.0)
	r.crew[0] = 5
	runner.check(r.pos.distance_to(w.sub.pos) > GATO.beam * 0.5, "launched clear of her side")
	runner.check(w.raft_of(5) == r, "the crewman is in her")
	var c := OceanWorld.new(GATO, 7)
	c.hull.setup([{"name": "a", "z0": -10.0, "z1": 0.0}], {}, {"helm": 0})
	c.apply_snapshot(w.to_snapshot())
	runner.check(c.rafts.size() == 1 and c.raft_of(5) != null and c.rafts[0].pos == r.pos, "a client gets the raft and who's in it")
	return true
