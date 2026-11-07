extends RefCounted
## The things in the depths (Monster): they come for a boat that's deep, hurt her, give up when
## she goes shallow, die to torpedoes; and the PA calls one up.

const TYPHOON := preload("res://data/subs/typhoon.tres")
const COMPS := [
	{"name": "forward torpedo room", "z0": -22.0, "z1": -8.0},
	{"name": "control room", "z0": -8.0, "z1": 0.0},
	{"name": "engine room", "z0": 0.0, "z1": 14.0},
]

var runner: Object


func _world(depth := 320.0) -> OceanWorld:
	var w := OceanWorld.new(TYPHOON, 5)
	w.hull.setup(COMPS, {"fwd": [0, 1], "aft": [1, 2]}, {"helm": 1, "dive": 1})
	w.sub.depth = depth
	w.sub.ballast = 1.0
	w.sub.ordered_depth = depth
	w.deep_life = false
	return w


func _run(w: OceanWorld, seconds: float, until := Callable(), dt := 0.1) -> void:
	for i in int(seconds / dt):
		w.step(dt)
		if until.is_valid() and until.call():
			return


func test_a_called_squid_comes_and_grabs_the_hull() -> bool:
	var w := _world()
	var acts: Array[String] = []
	w.event.connect(func(k: String, d: Dictionary) -> void:
		if k == "monster":
			acts.append(d.act))
	var m := w.add_monster("squid", 900.0, true)
	runner.check(m.depth >= m.floor_depth(), "it keeps to its depth: %.0f m" % m.depth)
	_run(w, 400.0, func() -> bool: return acts.has("grab"))
	runner.check(acts.has("call"), "it called as it stalked: %s" % str(acts))
	runner.check(acts.has("grab"), "it came in and grabbed the hull: %s" % str(acts))
	_run(w, Monster.HOLD_TIME + 2.0)
	runner.check(acts.has("release"), "it let go in the end: %s" % str(acts))
	runner.check(acts.count("squeeze") >= 2, "it squeezed while it held on: %d" % acts.count("squeeze"))
	return true


func test_it_gives_up_when_she_goes_shallow() -> bool:
	var w := _world()
	var acts: Array[String] = []
	w.event.connect(func(k: String, d: Dictionary) -> void:
		if k == "monster":
			acts.append(d.act))
	var m := w.add_monster("angler", 900.0, true)
	_run(w, 5.0)
	w.sub.depth = 80.0
	w.sub.ordered_depth = 80.0
	_run(w, 60.0)
	runner.check(acts.has("give_up") and m.state == "lurk", "it gave up below its depth: %s %s" % [m.state, str(acts)])
	runner.check(not acts.has("bite"), "and never reached her")
	return true


func test_torpedoes_kill_it() -> bool:
	var w := _world()
	var m := w.add_monster("megalodon", 900.0)
	var dead: Array[bool] = [] # (a lambda can't set a local)
	w.event.connect(func(k: String, d: Dictionary) -> void:
		if k == "monster" and d.act == "dead":
			dead.append(true))
	for i in m.hp:
		var t := Torpedo.new()
		t.pos = m.pos
		t.depth = m.depth
		t.alive = true
		w._check_hits(t)
		runner.check(not t.alive, "torpedo %d hit it" % (i + 1))
	runner.check(not dead.is_empty() and m.is_dead(), "%d torpedoes killed it" % int(Monster.KINDS.megalodon.hp))
	return true


func test_it_comes_round_on_the_snapshot() -> bool:
	var w := _world()
	w.add_monster("serpent", 900.0)
	var c := _world()
	c.apply_snapshot(w.to_snapshot())
	runner.check(c.monsters.size() == 1 and c.monsters[0].kind == "serpent", "a client sees the serpent")
	return true


func test_deep_waters_have_them() -> bool:
	var w := _world(400.0)
	w.deep_life = true
	_run(w, 600.0, func() -> bool: return not w.monsters.is_empty(), 0.5)
	runner.check(not w.monsters.is_empty(), "ten minutes at 400 m and something found her")
	var s := _world(40.0)
	s.deep_life = true
	_run(s, 600.0, Callable(), 0.5)
	runner.check(s.monsters.is_empty(), "nothing comes up to 40 m")
	return true


func test_the_pa_calls_one_up() -> bool:
	for line: String in ["spawn a kraken", "release the megalodon", "bring us a sea monster"]:
		var o := CrewCommand.parse(line)
		runner.check(not o.is_empty() and o[0].intent == "monster", "%s -> %s" % [line, str(o)])
	runner.check(CrewCommand.parse("spawn a kraken")[0].kind == "squid", "a kraken is the giant squid")
	return true
