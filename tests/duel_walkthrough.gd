extends SceneTree
## The enemy-sub fight on a real patrol: "enemy sub" on the PA in a sandbox starts one and the map
## goes dark; the patrol keeps running until the crew, told to, sink it.
##   godot --headless --path . -s tests/duel_walkthrough.gd [-- <sub>]

var _game: Node
var _sim: Node
var _phase := 0
var _t := 0.0


func _initialize() -> void:
	var net: Node = root.get_node("Net")
	_sim = root.get_node("Sim")
	net.mission = "sandbox"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		net.sub_key = args[0]
	net.mode = 1
	net.port = 7092
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
	var subs: Array = w.ships.filter(func(s: Variant) -> bool: return s.data.role == "sub")
	match _phase:
		0:
			if _t > 1.0:
				print("pa> enemy sub")
				_game.rq_pa("enemy sub")
				_phase = 1
				_t = 0.0
		1:
			if subs.is_empty() or not _game.crew.get("limited_map", false):
				_fail("no sub or no limited map")
			print("ok: %s %.1f km off, map limited, known here %d" % [subs[0].data.key, subs[0].pos.distance_to(w.sub.pos) / 1000.0, _game.known.at(w.sub.pos)])
			_phase = 2
			_t = 0.0
		2:
			if _t > 3.0:
				_game.rq_pa("sink the enemy sub")
				print("pa> sink the enemy sub: plan %s" % str(_game.bot_crew.plan))
				_t = 0.0
				_phase = 3
		3:
			if subs.is_empty() or subs[0].is_sinking():
				print("ok: sub sunk after %.0f s, hull leaks %d" % [_t, w.hull.leaks.size()])
				_phase = 4
				_t = 0.0
			elif _game.crew.result != "":
				print("boat lost in the fight: %s" % _game.crew.result)
				quit(0)
			elif _game.bot_crew.plan.is_empty() and int(_t) % 15 == 0 and int(_t) != int(_t - delta):
				_game.rq_pa("sink the enemy sub") # sonar may need to hear her first; don't restart a chase already on
			elif _t > 1200.0: # she runs and hides, so a hunt can be long
				_fail("never sunk: plan %s, range %.0f" % [str(_game.bot_crew.plan), subs[0].pos.distance_to(w.sub.pos)])
		4:
			if not _game.crew.get("limited_map", false):
				print("ok: the map is back")
				quit(0)
			elif _t > 30.0:
				_fail("map stayed limited")
	return false


func _fail(why: String) -> void:
	push_error("duel walkthrough: " + why)
	quit(1)
