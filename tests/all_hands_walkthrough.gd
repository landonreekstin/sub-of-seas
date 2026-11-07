extends SceneTree
## "All hands on deck" on a real patrol (Blaney): the boat fills, every post is manned, and the
## crew go after the objective by themselves until a ship it wants is sinking.
##   godot --headless --path . -s tests/all_hands_walkthrough.gd [-- <mission> [<sub>]]
## Exits 0 once the crowd is aboard and the crew have sunk a ship with nobody giving orders.

var _game: Node
var _sim: Node
var _phase := 0
var _t := 0.0


func _initialize() -> void:
	var net: Node = root.get_node("Net")
	_sim = root.get_node("Sim")
	var args := OS.get_cmdline_user_args()
	net.mission = args[0] if not args.is_empty() else "convoy"
	if args.size() > 1:
		net.sub_key = args[1]
	net.mode = 1
	net.port = 7100 + OS.get_process_id() % 2000 # its own port, so tests can run side by side
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
				_game.rq_pa("All hands on deck!")
				_phase = 1
				_t = 0.0
		1:
			if _t > 1.0:
				var crowd: int = _game.interior._crowd.size()
				var empty: Array = _game.bot_crew._watch_stations().filter(func(sid: String) -> bool: return _game.station_occupant(sid) == 0)
				if not _game.crew.get("full_crew", false) or crowd == 0 or not empty.is_empty():
					_fail("not all hands: crowd %d, empty posts %s" % [crowd, str(empty)])
				print("ok: all hands, %d bots, %d more standing about" % [_game.crew.bots.size(), crowd])
				_phase = 2
				_t = 0.0
		2:
			if w.ships.any(func(s: Variant) -> bool: return s.is_sinking()):
				print("ok: the crew sank a ship on their own after %.1f s; orders: %s" % [_t, _game.crew.orders])
				_game.rq_pa("stand down")
				_phase = 3
				_t = 0.0
			elif _t > 900.0:
				_fail("no ship sunk: plan %s, heading %.0f, depth %.0f" % [str(_game.bot_crew.plan), w.sub.heading, w.sub.depth])
		3:
			if _t > 1.0:
				if _game.crew.get("full_crew", false) or _game.interior._crowd.size() > 0:
					_fail("stand down left the crowd aboard")
				print("ok: stood down")
				quit(0)
	return false


func _fail(why: String) -> void:
	push_error("all hands walkthrough: " + why)
	quit(1)
