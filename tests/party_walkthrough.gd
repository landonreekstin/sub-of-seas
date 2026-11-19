extends SceneTree
## A damage party on any boat: every man stays inside the boat on his way (rooms, cross passages,
## the ladders), and goes through shut doors, shutting them again behind him.
##   godot --headless --path . -s tests/party_walkthrough.gd -- <sub>

var _game: Node
var _sim: Node
var _phase := 0
var _t := 0.0
var _doors_opened := 0
var _failed := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var net: Node = root.get_node("Net")
	_sim = root.get_node("Sim")
	net.mission = "cw_convoy" if not args.is_empty() and args[0] == "typhoon" else "convoy"
	net.sub_key = args[0] if not args.is_empty() else "gato"
	net.mode = 1
	net.port = int(OS.get_environment("TEST_PORT")) if OS.has_environment("TEST_PORT") else 7100 + OS.get_process_id() % 2000 # tests/walkthroughs.sh gives each its own
	Engine.time_scale = 4.0
	Engine.physics_ticks_per_second = 30
	change_scene_to_file.call_deferred("res://game/game.tscn")


func _process(delta: float) -> bool:
	if _game == null:
		if current_scene != null and current_scene.name == "Game":
			_game = current_scene
		return false
	var w: Variant = _sim.get("world")
	if w == null or _game.interior == null or w.hull.comps.is_empty():
		return false
	if _failed:
		return true
	_t += delta
	var hull: Variant = w.hull
	match _phase:
		0:
			if _t < 1.0:
				return false
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			var last: int = hull.comps.size() - 1
			hull.add_leak(0, 1, rng)
			hull.add_leak(last, 1, rng)
			hull.add_fire(last / 2, rng)
			var up: String = "periscope" if _game.interior.has_conning_tower else "helm"
			hull.break_station(up)
			for d: String in _game.crew.doors:
				_game.rq_door(d) # all shut
			_game.bot_crew.send_party()
			_phase = 1
			_t = 0.0
		1:
			for t: Dictionary in hull.teams:
				if not _inside(t.p):
					_fail("a man outside the boat at %s" % str(t.p))
			for d: String in _game.crew.doors:
				if _game.crew.doors[d]:
					_doors_opened += 1
			if hull.leaks.is_empty() and hull.fires.is_empty() and hull.broken.is_empty():
				if _doors_opened == 0:
					_fail("nobody opened a door")
				_phase = 2
				_t = 0.0
			elif _t > 400.0:
				_fail("still broken: %s %s %s teams %s" % [str(hull.leaks), str(hull.fires), str(hull.broken), str(hull.teams)])
		2:
			if _t < 2.0:
				return false
			for d: String in _game.crew.doors:
				if _game.crew.doors[d]:
					_fail("door %s left open" % d)
			print("ok: %s party fixed it all, stayed inside, doors shut behind them" % _game.interior.sub_class.key)
			quit(0)
	return false


func _inside(p: Vector3) -> bool:
	var i: Variant = _game.interior
	for c: Dictionary in i.compartments:
		if absf(p.x - float(c.get("x", 0.0))) <= 2.1 and p.z >= float(c.z0) - 0.3 and p.z <= float(c.z1) + 0.3:
			var y: float = c.get("y", 0.0)
			if p.y >= y - 0.1 and p.y <= y + 3.2:
				return true
	if i.sub_class.key == "typhoon":
		var layout: Variant = load("res://interior/typhoon_layout.gd") # not by name: this script compiles before the autoloads
		for cr: Array in layout.CROSS: # the short passages between the hulls
			if absf(p.z - float(cr[2])) <= 0.9 and absf(p.x) <= 6.0 and absf(p.y) < 0.2:
				return true
		if absf(p.x) < 0.6 and absf(p.z - float(layout.HATCH_Z)) < 1.5: # the ladder
			return true
	return false


func _fail(why: String) -> void:
	printerr("party walkthrough: " + why)
	_failed = true
	quit(1)
