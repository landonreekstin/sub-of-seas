extends SceneTree
## The Typhoon on a real Cold War patrol: all hands, a band, a first mate who sends the damage
## parties to real damage until it's fixed, and an order to sink a ship.
##   godot --headless --path . -s tests/typhoon_walkthrough.gd

var _game: Node
var _sim: Node
var _phase := 0
var _t := 0.0


func _initialize() -> void:
	var net: Node = root.get_node("Net")
	_sim = root.get_node("Sim")
	net.mission = "cw_convoy"
	net.sub_key = "typhoon"
	net.mode = 1
	net.port = 7093
	Engine.time_scale = 6.0
	Engine.physics_ticks_per_second = 30
	change_scene_to_file.call_deferred("res://game/game.tscn")


func _process(delta: float) -> bool:
	if _game == null:
		if current_scene != null and current_scene.name == "Game":
			_game = current_scene
		return false
	var w: Variant = _sim.get("world")
	if w == null:
		return false
	_t += delta
	match _phase:
		0:
			if _t > 1.0:
				_game.rq_pa("all hands")
				_phase = 1
				_t = 0.0
		1:
			if _t < 1.0:
				return false
			if not _game.crew.get("full_crew", false) or not _game.crew.bots.has("first_mate") or not _game.crew.bots.has("helm"):
				_fail("all hands: %s" % str(_game.crew.bots.keys()))
			print("ok: all hands, %d bots" % _game.crew.bots.size())
			var hull: Variant = w.hull
			var rng := RandomNumberGenerator.new()
			hull.add_leak(14, 1, rng)
			hull.add_fire(11, rng)
			hull.break_station("helm")
			_game.rq_pa("band play")
			_phase = 2
			_t = 0.0
		2:
			var hull: Variant = w.hull
			if _t > 1.0 and not _game.band_playing():
				_fail("the band isn't playing")
			if hull.leaks.is_empty() and hull.fires.is_empty() and hull.broken.is_empty():
				print("ok: the parties fixed it all in %.0f s; band on; news %d" % [_t, int(_game.crew.get("mate_news", 0))])
				_game.rq_pa("stop the music")
				_game.rq_pa("sink the nearest ship")
				_phase = 3
				_t = 0.0
			elif _t > 400.0:
				_fail("still broken: %s %s %s teams %s" % [str(hull.leaks), str(hull.fires), str(hull.broken), str(hull.teams)])
		3:
			if w.ships.any(func(s: Variant) -> bool: return s.is_sinking()):
				print("ok: a ship is sinking after %.0f s" % _t)
				quit(0)
			elif _t > 500.0:
				_fail("no ship sunk: %s, depth %.0f" % [str(_game.bot_crew.plan), w.sub.depth])
	return false


func _fail(why: String) -> void:
	push_error("typhoon walkthrough: " + why)
	quit(1)
