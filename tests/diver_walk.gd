extends SceneTree
## A diver outside while she dives (Blaney: dive suits and spots to hold on to; a button back to
## the boat when she's left him behind; since then the hatch opens any time, tests/god_out.gd):
## a real player climbs out, suits up at the locker, holds on at the bow, rides her down, lets go
## and is left behind as she moves on, hauls himself back on his lifeline, and once she surfaces
## goes below and the suit goes back in the locker.
##   godot --headless --path . -s tests/diver_walk.gd -- <sub>

var _game: Node
var _step := 0
var _t := 0.0
var _bad: Array[String] = []
var _mark := Vector3.ZERO
var _D: GDScript


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var net: Node = root.get_node("Net")
	var sub: String = args[0] if not args.is_empty() else "gato"
	net.mission = "cw_convoy" if sub == "typhoon" else "convoy"
	net.sub_key = sub
	net.debug_depth = 0.0
	net.mode = 1
	net.port = 7100 + OS.get_process_id() % 2000 # its own port, so tests can run side by side
	Engine.time_scale = 3.0
	change_scene_to_file.call_deferred("res://game/game.tscn")


func _fail(why: String) -> void:
	_bad.append(why)


func _next() -> void:
	_step += 1
	_t = 0.0


func _physics_process(delta: float) -> bool:
	if _game == null:
		if current_scene != null and current_scene.name == "Game":
			_game = current_scene
		return false
	var me: Variant = _game.local_player
	var deck: Variant = _game.get("deck")
	var world: Variant = root.get_node("Sim").get("world")
	if me == null or deck == null or world == null:
		return false
	if _D == null:
		_D = load("res://game/deck.gd")
	_t += delta
	var o: Vector3 = _D.ORIGIN
	var sub: Variant = world.sub
	var suits: Dictionary = _game.crew.get("suits", {})
	match _step:
		0:
			if _t < 1.0:
				return false
			me.go_on_deck()
			_next()
		1: # without a suit she won't dive
			if _t < 1.0:
				return false
			_game.apply_order("ballast", "vent", null, 1)
			if sub.vents_open:
				_fail("she vented with a man on deck in no suit")
			for n: Node in deck.get_children():
				if n.has_method("get_prompt") and "Put on" in str(n.get_prompt(me)):
					n.interact(me)
			_next()
		2:
			if _t < 0.5:
				return false
			if not suits.has(me.peer_id):
				_fail("the locker didn't suit him up")
			deck.grab(0)
			_game.apply_order("ballast", "vent", null, 1)
			_game.apply_order("dive", "depth", 30.0, 1)
			sub.telegraph = 2
			if not sub.vents_open:
				_fail("she wouldn't dive with a suited diver holding on")
			_next()
		3: # riding her down
			if sub.depth < 20.0:
				if _t > 120.0:
					_fail("she never got down (%.1f m)" % sub.depth)
					_step = 9
				return false
			if not _D.is_out(me.global_position) or deck.holding != 0:
				_fail("the diver didn't stay holding on as she dived")
			if (me.global_position - o).distance_to(deck.holds[0]) > 0.3:
				_fail("holding on, he isn't at the rail: %s" % str(me.global_position - o))
			if not _D.is_under(me.global_position):
				_fail("dived, the diver isn't under water")
			if "shots" in OS.get_cmdline_user_args(): # under xvfb-run: what the lookout sees from the bow rail
				me.rotation.y = 0.0
				me.head.rotation.x = -0.25
				await process_frame
				await process_frame
				root.get_viewport().get_texture().get_image().save_png("res://screenshots/diver_eye.png")
			deck.grab(-1)
			me.global_position = o + Vector3(float(deck.dims.beam) * 0.5 + 3.0, 0.0, (me.global_position - o).z) # pushed off clear of her side
			_mark = me.global_position - o
			_next()
		4: # let go: she goes on without him
			if _t < 8.0:
				return false
			var at: Vector3 = me.global_position - o
			if at.z - _mark.z < 8.0:
				_fail("let go, he wasn't left behind: %s -> %s" % [str(_mark), str(at)])
			if not _D.is_out(me.global_position):
				_fail("let go, he ended up below")
			_next()
		5: # far off: the lifeline
			if not deck.far_from_boat(me.global_position - o) and _t < 60.0:
				return false
			if not deck.far_from_boat(me.global_position - o):
				_fail("never far enough off for the lifeline: %s" % str(me.global_position - o))
			deck.haul_back(me)
			if deck.holding < 0:
				_fail("the lifeline didn't bring him back to a rail")
			_game.apply_order("dive", "depth", 0.0, 1)
			_game.apply_order("ballast", "blow", null, 1)
			_next()
		6: # she surfaces
			if sub.depth > 1.0:
				if _t > 120.0:
					_fail("she never surfaced (%.1f m)" % sub.depth)
					_step = 9
				return false
			deck.grab(-1)
			me.global_position = deck.hatch_spot()
			me.go_below()
			_next()
		7:
			if _t < 0.5:
				return false
			if _D.is_out(me.global_position):
				_fail("surfaced, he couldn't go below")
			if suits.has(me.peer_id):
				_fail("below, he's still in the suit")
			_step = 9
		9:
			print("diver walk (%s): %s" % [_game.sub_class.key, "ok" if _bad.is_empty() else str(_bad)])
			quit(1 if not _bad.is_empty() else 0)
			return true
	return false
