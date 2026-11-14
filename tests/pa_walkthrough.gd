extends SceneTree
## Plays the PA end to end on a real patrol, through the request a player sends: dive to the
## bottom, a course and speed, then "sink the ship to the east" until a ship goes down.
##   godot --headless --path . -s tests/pa_walkthrough.gd [-- <mission> [<sub> [<realism>]]]
## (third argument: the realism level). Exits 0 when every order has been seen carried out.

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
	if args.size() > 2:
		net.realism = args[2]
	net.mode = 1
	net.port = int(OS.get_environment("TEST_PORT")) if OS.has_environment("TEST_PORT") else 7100 + OS.get_process_id() % 2000 # tests/walkthroughs.sh gives each its own
	Engine.time_scale = 6.0
	Engine.physics_ticks_per_second = 30
	change_scene_to_file.call_deferred("res://game/game.tscn")


func _say(text: String) -> void:
	print("pa> ", text)
	_game.rq_pa(text)
	_t = 0.0
	_phase += 1


func _process(delta: float) -> bool:
	if _game == null:
		if current_scene != null and current_scene.name == "Game":
			_game = current_scene
		return false
	var w: Variant = _sim.get("world")
	if w == null:
		return false
	_t += delta
	var sub: Variant = w.sub
	match _phase:
		0:
			if _t > 1.0:
				print("start: heading %.0f depth %.0f, ships: %s" % [sub.heading, sub.depth, ", ".join(w.ships.map(func(s: Variant) -> String: return "%s %.0f km brg %.0f" % [s.data.key, s.pos.distance_to(sub.pos) / 1000.0, _b(sub.pos, s.pos)]))])
				_say("banana pizza")
		1:
			if _t > 1.0:
				_say("come to 045, slow, and dive to 40")
		2:
			if absf(wrapf(sub.heading - 45.0, -180.0, 180.0)) < 3.0 and absf(sub.depth - 40.0) < 2.0:
				print("ok: course and depth (%.1f s)" % _t)
				_say("what's wrong")
			elif _t > 120.0:
				_fail("course or depth never reached: h %.0f d %.0f bots %s" % [sub.heading, sub.depth, str(_game.crew.bots.keys())])
		3:
			if _t > 1.0:
				_say("sink the nearest ship")
		4:
			var sunk: bool = w.ships.any(func(s: Variant) -> bool: return s.is_sinking())
			if sunk:
				print("ok: a ship is sinking after %.1f s, torpedoes left %d" % [_t, _game.crew.reserve])
				quit(0)
			elif _t > 400.0:
				_fail("no ship sunk: plan %s, heading %.0f, depth %.0f, tubes %s" % [str(_game.bot_crew.plan), sub.heading, sub.depth, str(_game.crew.tubes.slice(0, 2))])
	return false


func _b(a: Vector2, b: Vector2) -> float:
	var d := b - a
	return fposmod(rad_to_deg(atan2(d.x, d.y)), 360.0)


func _fail(why: String) -> void:
	push_error("pa walkthrough: " + why)
	quit(1)
