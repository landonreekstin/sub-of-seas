extends SceneTree
## Swimming (Blaney: "down to the sea floor, out of the sub while dived, and in flooded rooms"):
## over the side, Ctrl dives under, and he swims all the way down to the sea floor and stands on
## it, never through it; back aboard, out of the escape trunk at the bow; then in a flooded
## compartment he swims up off the deck and floats.
##   godot --headless --path . -s tests/swim_walk.gd -- [<sub>]

var _game: Node
var _step := 0
var _t := 0.0
var _bad: Array[String] = []
var _D: GDScript
var _deepest := 0.0
var _mark := Vector3.ZERO


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var net: Node = root.get_node("Net")
	var sub: String = args[0] if not args.is_empty() else "gato"
	net.mission = "cw_convoy" if sub == "typhoon" else "convoy"
	net.sub_key = sub
	net.debug_depth = 0.0
	net.mode = 1
	net.port = 7300 + OS.get_process_id() % 500
	Engine.time_scale = 4.0
	change_scene_to_file.call_deferred("res://game/game.tscn")


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
	match _step:
		0:
			if _t < 1.5:
				return false
			_game.crew.get_or_add("god", {})[me.peer_id] = true # nothing knocks him out on the way down
			me.go_on_deck()
			_next()
		1: # over the side and under
			if _t < 0.5:
				return false
			me.global_position = o + Vector3(float(deck.dims.beam) * 0.5 + 4.0, -0.5, 0.0)
			Input.action_press("crouch")
			_next()
		2:
			var floor_y: float = _D.floor_at(me.global_position)
			_deepest = maxf(_deepest, o.y - me.global_position.y)
			if me.global_position.y < floor_y - 0.5:
				_bad.append("went through the sea floor (%.1f under it)" % (floor_y - me.global_position.y))
			if int(_t) % 10 == 0 and int(_t) != int(_t - delta):
				print("swim: %.0f m down, floor at %.0f m" % [o.y - me.global_position.y, o.y - floor_y])
			if me.global_position.y < floor_y + 0.6 and _t > 2.0:
				print("swim: on the sea floor at %.0f m after %.0f s" % [o.y - floor_y, _t])
				Input.action_release("crouch")
				_next()
			elif _t > 600.0:
				_bad.append("never reached the sea floor (%.0f m down, floor %.0f)" % [o.y - me.global_position.y, o.y - floor_y])
				Input.action_release("crouch")
				_next()
		3: # back aboard and out of the escape trunk forward
			me.go_below()
			me.go_on_deck(true)
			var bow: Vector3 = deck.bow_spot()
			if me.global_position.distance_to(bow) > 0.5 or not _D.is_out(me.global_position):
				_bad.append("the escape trunk didn't put him out at the bow")
			if not _game.interior.find_children("*", "EscapeTrunk", true, false).size() > 0:
				_bad.append("no escape trunk in the boat")
			me.go_below()
			_next()
		4: # a flooded room: the compartment he's in fills to the deckhead
			if _t < 1.0:
				me.global_position = _game.interior.spawn_points[0] # on the control room's deck
				return false
			var hull: Variant = world.hull
			var c: int = hull.comp_at_pos(me.position)
			hull.comps[c].water = 1.0
			_mark = me.position
			Input.action_press("jump")
			_next()
		5:
			var hull: Variant = world.hull
			hull.comps[hull.comp_at_pos(_mark)].water = 1.0 # kept full: it runs off through the open doors
			if _t < 2.0:
				return false
			Input.action_release("jump")
			if me.position.y < _mark.y + 0.4:
				_bad.append("didn't swim up off the deck in the flooded room (%.2f)" % (me.position.y - _mark.y))
			if me.eye_under() < 0.0:
				_bad.append("the flood over his head isn't under water")
			print("swim: in the flooded room, %.1f m up off the deck" % (me.position.y - _mark.y))
			_next()
		6:
			print("swim_walk %s: %s" % [root.get_node("Net").sub_key, "ok" if _bad.is_empty() else "FAIL " + "; ".join(_bad)])
			quit(0 if _bad.is_empty() else 1)
			return true
	return false


