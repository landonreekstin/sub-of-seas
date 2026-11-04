extends RefCounted
## The enemy submarine and the map that only shows what we've seen.

const GATO := preload("res://data/subs/gato.tres")
const I_BOAT := preload("res://data/ships/i_boat.tres")
const COMPS := [
	{"name": "forward torpedo room", "z0": -22.0, "z1": -8.0},
	{"name": "control room", "z0": -8.0, "z1": 0.0},
	{"name": "engine room", "z0": 0.0, "z1": 14.0},
]

var runner: Object


func _world() -> OceanWorld:
	var w := OceanWorld.new(GATO, 5)
	w.hull.setup(COMPS, {"fwd": [0, 1], "aft": [1, 2]}, {})
	w.sub.depth = 40.0
	w.sub.ordered_depth = 40.0
	w.sub.ballast = 1.0
	return w


func test_a_sub_hunts_and_fires() -> bool:
	var w := _world()
	var s := Formations.enemy_sub(w, w.sub.pos + Vector2(0, 2500), 180.0, 4.0, "i_boat")
	runner.check(s.ai is EnemySubAI and s.submerged(), "dived, with its own brain")
	s.awareness = 1.0
	var fired := [0]
	w.event.connect(func(k: String, _d: Dictionary) -> void:
		if k == "enemy_torpedo":
			fired[0] += 1)
	for i in 600:
		w.step(0.1)
	runner.check(fired[0] >= 2, "hears us and fires a pair (%d)" % fired[0])
	return true


func test_its_torpedo_hurts_us() -> bool:
	var w := _world()
	var s := w.add_ship(I_BOAT, w.sub.pos + Vector2(0, 600), 180.0, 0.0)
	s.depth = 40.0
	s.passive = true
	w.fire_enemy_torpedo(s, 180.0)
	for i in 400:
		w.step(0.1)
	runner.check(not w.hull.leaks.is_empty() or not w.hull.fires.is_empty() or not w.hull.broken.is_empty(), "a hit does real damage")
	runner.check(w.torpedoes.is_empty(), "and the torpedo is spent")
	return true


func test_our_torpedo_needs_her_depth() -> bool:
	var w := _world()
	var s := w.add_ship(I_BOAT, w.sub.pos + w.sub.direction() * 900.0, 90.0, 0.0)
	s.passive = true
	s.depth = 150.0 # far under what we're firing at
	w.fire_torpedo(0.0)
	for i in 300:
		w.step(0.1)
	runner.check(not s.is_sinking(), "runs over her when she's much deeper")
	s.depth = w.sub.depth + 5.0
	w.fire_torpedo(0.0)
	for i in 300:
		w.step(0.1)
	runner.check(s.is_sinking(), "hits at about her depth")
	return true


func test_the_limited_map() -> bool:
	var w := _world()
	var k := ChartKnown.new()
	k.start(w.sub.pos)
	runner.check(k.at(w.sub.pos) == 0, "starts unknown")
	k.sweep(w) # dived, scope down
	runner.check(k.at(w.sub.pos) == ChartKnown.SONAR, "dived: only the echo sounder under us")
	runner.check(k.at(w.sub.pos + Vector2(2000, 0)) == 0, "and nothing 2 km off")
	k.reveal(w.sub.pos, ChartKnown.PING_RANGE, ChartKnown.SONAR)
	runner.check(k.at(w.sub.pos + Vector2(2000, 0)) == ChartKnown.SONAR, "a ping reaches further")
	w.sub.depth = 0.0
	k.sweep(w)
	runner.check(k.at(w.sub.pos + Vector2(3000, 0)) & ChartKnown.SIGHT != 0, "surfaced, we see for miles")
	var v := k.version
	k.sweep(w)
	runner.check(k.version == v, "nothing new, no redraw")
	return true
