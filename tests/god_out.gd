extends SceneTree
## Out of the boat while she's dived, and god mode (Blaney: "make it so i can also exit the boat
## at any time", and "god mode" on the PA: super speed, invincible, super swimming "so i can catch
## up to subs and watch them from the outside"). Dived at 60 m: a crewman climbs out and is put in
## a dive suit, not sent below; "god mode" on the PA, and with her at full speed he swims after her
## and keeps up; "god mode off"; back down the hatch.
##   godot --headless --path . -s tests/god_out.gd -- <sub>

var _game: Node
var _step := 0
var _t := 0.0
var _far := 0.0
var _D: GDScript


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var net: Node = root.get_node("Net")
	net.sub_key = args[0] if not args.is_empty() else "gato"
	net.mission = "cw_convoy" if net.sub_key == "typhoon" else "convoy"
	net.debug_depth = 60.0
	net.start_bots = PackedStringArray(["helm", "dive", "ballast"])
	net.mode = 1
	net.port = 7100 + OS.get_process_id() % 800
	Engine.time_scale = 2.0
	change_scene_to_file.call_deferred("res://game/game.tscn")


func _done(ok: bool, why: String) -> void:
	print(("ok: " if ok else "FAIL: ") + why)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	quit(0 if ok else 1)


func _physics_process(delta: float) -> bool:
	if _game == null:
		if current_scene != null and current_scene.name == "Game":
			_game = current_scene
		return false
	var me: Variant = _game.local_player
	var w: Variant = root.get_node("Sim").get("world")
	if me == null or w == null or _game.get("deck") == null:
		return false
	if _D == null:
		_D = load("res://game/deck.gd")
	_t += delta
	var crew: Dictionary = _game.crew
	match _step:
		0: # dived; out of the hatch, as the bridge hatch's E does
			if _t < 2.0:
				return false
			if not _D.can_go_out():
				_done(false, "the hatch won't open dived")
				return true
			me.go_on_deck()
			_step = 1
			_t = 0.0
		1: # out in the sea, suited, and still out 3 s on
			if _t < 3.0:
				return false
			if not _D.is_out(me.global_position):
				_done(false, "sent back below (y %.1f)" % me.global_position.y)
				return true
			if not crew.get("suits", {}).has(me.peer_id):
				_done(false, "no dive suit on, dived")
				return true
			print("god_out: out at %.1f m under, suited" % (w.sub.depth - (me.global_position.y - _D.ORIGIN.y)))
			_game.rq_pa("god mode")
			_step = 2
			_t = 0.0
		2: # god mode on: she goes full ahead and he swims after her, looking forward
			if _t < 1.0:
				return false
			if not crew.get("god", {}).has(me.peer_id):
				_done(false, "god mode didn't come on")
				return true
			crew.bots.helm.auto = false
			crew.bots.helm.speed = 4
			crew.bots.helm.course = w.sub.heading
			me.rotation.y = 0.0
			me.head.rotation.x = 0.0
			# Clear of her, out to the side and 60 m astern: he has to catch her and pass her bow.
			me.global_position = _D.ORIGIN + Vector3(30.0, w.sub.depth - 15.0 - 1.0, _game.deck.dims.length * 0.5 + 60.0)
			Input.action_press("move_forward")
			Input.action_press("sprint")
			_step = 3
			_t = 0.0
		3:
			var local: Vector3 = me.global_position - _D.ORIGIN
			_far = maxf(_far, absf(local.z))
			if int(_t) % 5 == 0 and int(_t - delta) % 5 != 0:
				print("god_out: %2d s speed %.1f m/s, %.0f m aft of her middle" % [int(_t), w.sub.speed, local.z])
			if local.z < -float(_game.deck.dims.length) * 0.5 - 10.0:
				print("god_out: past her bow at %d s" % int(_t))
			elif _t < 40.0:
				return false
			Input.action_release("move_forward")
			Input.action_release("sprint")
			if w.sub.speed < 5.0 and _t >= 40.0:
				_done(false, "she never got going (%.1f m/s)" % w.sub.speed)
				return true
			if local.z > -float(_game.deck.dims.length) * 0.5 - 10.0:
				_done(false, "never caught her up (%.0f m astern of her middle)" % local.z)
				return true
			_game.rq_pa("god mode off")
			_step = 4
			_t = 0.0
		4:
			if _t < 1.0:
				return false
			if crew.get("god", {}).has(me.peer_id):
				_done(false, "god mode didn't go off")
				return true
			me.go_below()
			_step = 5
			_t = 0.0
		5:
			if _t < 2.0:
				return false
			if _D.is_out(me.global_position):
				_done(false, "couldn't get back below")
				return true
			_done(true, "out dived, kept up with her at %.1f m/s in god mode, back below (%s)" % [w.sub.speed, root.get_node("Net").sub_key])
			return true
	return false
