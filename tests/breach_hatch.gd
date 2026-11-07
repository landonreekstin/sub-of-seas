extends SceneTree
## Crash surface and out (Blaney: "it was staying locked even though we were surfaced"): the
## boat dived deep with bot crewmen at the yokes and the ballast, "crash surface" on the PA (or
## X twice on the ballast, or the bot planesman told to surface), and once she's up the hatch
## must open and stay open. "dive": nobody at the ballast, the player presses 1 (surface) at the
## dive station (Blaney: "i cannot open the hatch even though i pressed 1 to surface").
##   godot --headless --path . -s tests/breach_hatch.gd -- <sub> [pa | ballast | planesman | dive]

var _game: Node
var _t := 0.0
var _how := "pa"
var _ok_since := -1.0
var _D: GDScript


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var net: Node = root.get_node("Net")
	var sub: String = args[0] if not args.is_empty() else "typhoon"
	_how = args[1] if args.size() > 1 else "pa"
	net.mission = "cw_convoy" if sub == "typhoon" else "convoy"
	net.sub_key = sub
	net.debug_depth = 80.0
	net.start_bots = PackedStringArray(["helm"] if _how == "dive" else ["helm", "dive", "ballast"])
	net.mode = 1
	net.port = 7100 + OS.get_process_id() % 2000 # its own port, so tests can run side by side
	Engine.time_scale = 2.0
	change_scene_to_file.call_deferred("res://game/game.tscn")


func _physics_process(delta: float) -> bool:
	if _game == null:
		if current_scene != null and current_scene.name == "Game":
			_game = current_scene
		return false
	var w: Variant = root.get_node("Sim").get("world")
	if w == null or _game.local_player == null:
		return false
	if _D == null:
		_D = load("res://game/deck.gd")
	var before := _t
	_t += delta
	if before < 3.0 and _t >= 3.0:
		match _how:
			"pa":
				_game.rq_pa("crash surface")
			"ballast":
				_game.apply_order("ballast", "emergency", null, -1)
			"planesman": # E at him, [1] surface: he goes off his own initiative and takes her up
				var b: Dictionary = _game.crew.bots.dive
				b.auto = false
				b.depth = 0.0
			"dive":
				_game.apply_order("dive", "depth", 0.0, -1)
	var sub: Variant = w.sub
	if int(_t) != int(before) and int(_t) % 5 == 0:
		print("breach_hatch: %3d s depth %.1f ordered %.1f ballast %.2f vents %s blowing %d hatch %s" % [int(_t), sub.depth, sub.ordered_depth, sub.ballast, sub.vents_open, sub.blowing, (sub.is_surfaced() and not sub.vents_open)])
	if (sub.is_surfaced() and not sub.vents_open):
		if _ok_since < 0.0:
			_ok_since = _t
	elif _ok_since >= 0.0:
		print("FAIL: the hatch shut again at %d s (depth %.1f, vents %s)" % [int(_t), sub.depth, sub.vents_open])
		quit(1)
		return true
	if _t > 150.0:
		if _ok_since < 0.0 or _t - _ok_since < 30.0:
			print("FAIL: still locked after %d s (depth %.1f, vents %s)" % [int(_t), sub.depth, sub.vents_open])
			quit(1)
		else:
			print("ok: up and the hatch open (%s, %s)" % [_how, root.get_node("Net").sub_key])
			quit(0)
		return true
	return false
