extends RefCounted
## Rain squalls (M12): where it rains, what it hides, how they come and go, and that they
## replicate.

const GATO := preload("res://data/subs/gato.tres")
const DESTROYER := preload("res://data/ships/destroyer.tres")

var runner: Object


func _world(seed_value := 5) -> OceanWorld:
	var w := OceanWorld.new(GATO, seed_value)
	w.sub.depth = 0.0 # surfaced: the lookouts' best chance
	return w


func test_rain_is_heaviest_in_the_middle() -> bool:
	var c := Conditions.new()
	var rng := RandomNumberGenerator.new()
	var s := c.add_squall(Vector2(1000, 0), rng, 600.0)
	runner.check(is_equal_approx(c.rain_at(Vector2(1000, 0)), 1.0), "pouring in the middle")
	runner.check(c.rain_at(Vector2(1000 + s[2] * 0.8, 0)) > 0.0, "lighter toward the edge")
	runner.check(c.rain_at(Vector2(1000 + s[2] * 0.8, 0)) < 0.9, "but not as heavy")
	runner.check(c.rain_at(Vector2(1000 + s[2] + 10.0, 0)) == 0.0, "dry outside it")
	runner.check(c.rain_between(Vector2(-5000, 0), Vector2(7000, 0)) > 0.9, "rain between two dry points still hides")
	runner.check(c.sea_at(Vector2(1000, 0)) > float(c.sea_state), "the sea runs higher under it")
	return true


func test_a_squall_builds_and_dies() -> bool:
	var s := [0.0, 0.0, 2000.0, 0.0, 1000.0]
	runner.check(Conditions.squall_strength(s) == 0.0, "nothing at first")
	s[3] = Conditions.SQUALL_BUILD * 0.5
	runner.check(is_equal_approx(Conditions.squall_strength(s), 0.5), "half built")
	s[3] = 500.0
	runner.check(Conditions.squall_strength(s) == 1.0, "full in the middle of its life")
	s[3] = 1000.0 - Conditions.SQUALL_BUILD * 0.25
	runner.check(Conditions.squall_strength(s) < 0.3, "dying away at the end")
	return true


func test_squalls_hide_the_boat_from_lookouts() -> bool:
	var w := _world()
	var dd := w.add_ship(DESTROYER, Vector2(0, 5000), 90.0, 10.0)
	Detection.conditions = w.conditions
	var clear := Detection.awareness_gain(dd, w.sub)
	w.conditions.add_squall(w.sub.pos, w.rng, 500.0)
	var rain := Detection.awareness_gain(dd, w.sub)
	runner.check(clear > 0.0, "surfaced at 5 km the destroyer sees her in clear weather (%.4f)" % clear)
	runner.check(rain < clear * 0.5, "under a squall it hardly does (%.4f)" % rain)
	runner.check(Aircraft.sight_range(w.sub, w.conditions) < Aircraft.sight_range(w.sub, Conditions.new()) * 0.5, "nor do planes")
	return true


func test_the_host_keeps_squalls_about_and_they_drift() -> bool:
	var w := _world()
	w.conditions.setup_weather(-1, w.sub.pos, w.rng)
	runner.check(w.conditions.squalls.size() == Conditions.SQUALLS_BY_SEA[1], "a moderate sea has its squalls from the start")
	var first: Array = w.conditions.squalls[0].duplicate()
	for i in 600:
		w.step(0.1)
	var now: Array = w.conditions.squalls[0]
	var moved := Vector2(now[0] - first[0], now[1] - first[1])
	runner.check(moved.length() > 100.0, "they drift (%.0f m in a minute)" % moved.length())
	runner.check(absf(wrapf(rad_to_deg(atan2(moved.x, moved.y)) - w.conditions.wind, -180.0, 180.0)) < 1.0, "downwind")
	for i in 2400: # 40 minutes: every one has blown through and been replaced
		w.step(1.0)
	runner.check(w.conditions.squalls.size() == w.conditions.squall_count, "still %d about" % w.conditions.squall_count)
	runner.check(w.conditions.squalls.all(func(s: Array) -> bool: return s[3] < 2400.0), "all new ones")
	var clear := Conditions.new()
	clear.sea_state = 2
	clear.setup_weather(0, Vector2.ZERO, w.rng)
	runner.check(clear.squalls.is_empty() and clear.squall_count == 0, "0 means clear weather")
	return true


func test_squalls_replicate() -> bool:
	var w := _world()
	w.conditions.setup_weather(2, w.sub.pos, w.rng)
	var c := _world(9)
	c.apply_snapshot(w.to_snapshot())
	runner.check(c.conditions.squalls.size() == 2, "the client has both")
	var a: Array = w.conditions.squalls[1]
	var b: Array = c.conditions.squalls[1]
	runner.check(absf(a[0] - b[0]) < 0.01 and absf(a[2] - b[2]) < 0.01, "in the same place, the same size")
	runner.check(is_equal_approx(c.conditions.wind, w.conditions.wind), "on the same wind")
	c.step(1.0, false)
	runner.check(c.conditions.squalls.size() == 2, "a client drifts them but never ends one")
	return true
