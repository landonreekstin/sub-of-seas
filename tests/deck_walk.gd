extends SceneTree
## Out on deck and back (Blaney: "the sub doesn't let you get back in, and you have to clip
## through the sub to even see the hatch"): a real player climbs out of the hatch, stands on the
## casing, walks fore and aft, finds the hatch by looking at it, swims off the side, climbs the
## rungs back aboard and goes below.
##   godot --headless --path . -s tests/deck_walk.gd -- <sub>

var _game: Node
var _step := 0
var _t := 0.0
var _bad: Array[String] = []
var _mark := Vector3.ZERO
var _D: GDScript ## Deck and OwnBoat, loaded once the autoloads are up
var _O: GDScript


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var net: Node = root.get_node("Net")
	var sub: String = args[0] if not args.is_empty() else "typhoon"
	net.mission = "cw_convoy" if sub == "typhoon" else "convoy"
	net.sub_key = sub
	net.debug_depth = 0.0
	net.mode = 1
	net.port = 7096
	Engine.time_scale = 2.0
	change_scene_to_file.call_deferred("res://game/game.tscn")


func _fail(why: String) -> void:
	_bad.append(why)


func _physics_process(delta: float) -> bool:
	if _game == null:
		if current_scene != null and current_scene.name == "Game":
			_game = current_scene
		return false
	var me: Variant = _game.local_player
	var deck: Variant = _game.get("deck")
	if me == null or deck == null or root.get_node("Sim").get("world") == null:
		return false
	if _D == null:
		_D = load("res://game/deck.gd")
		_O = load("res://world/own_boat.gd")
	_t += delta
	var d: Dictionary = deck.dims
	var o: Vector3 = _D.ORIGIN
	match _step:
		0: # up the hatch
			if _t < 1.0:
				return false
			me.go_on_deck()
			_step = 1
			_t = 0.0
		1: # he should be standing on the casing, not stuck in anything
			if _t < 1.5:
				return false
			var at: Vector3 = me.global_position - o
			if not me.is_on_floor() or absf(at.y - _O.deck_y(d, _O.t_of(d, at.z))) > 0.4:
				_fail("not standing on the casing after climbing out: %s" % str(at))
			# turn round and look down at the hatch
			me.rotation.y = PI
			me.head.rotation.x = deg_to_rad(-55.0)
			_step = 2
			_t = 0.0
		2:
			if _t < 0.3:
				return false
			me.ray.force_raycast_update()
			var n: Node = me._interact_target()
			if n == null or not n.has_method("get_prompt") or n.get_prompt(me) != "[E] Go below":
				_fail("can't find the hatch looking down at it from where you climb out (%s)" % str(n))
			else:
				n.interact(me)
				if _D.is_out(me.global_position):
					_fail("going below left him on deck")
			me.go_on_deck() # out again for the walk
			me.head.rotation.x = 0.0
			me.rotation.y = PI # walk aft along the centre line, past the fin's side
			me.global_position = o + Vector3(float(d.ct_w) * 0.5 + 1.2, _O.deck_y(d, _O.t_of(d, float(d.ct_z))) + 0.1, float(d.ct_z) - float(d.ct_len) * 0.5 - 1.0)
			_mark = me.global_position
			Input.action_press("move_forward")
			_step = 3
			_t = 0.0
		3: # aft past the fin
			if _t < 4.0:
				return false
			Input.action_release("move_forward")
			if (me.global_position - _mark).length() < 6.0:
				_fail("walking aft past the fin got stuck at %s" % str(me.global_position - o))
			# off the side into the sea by the rungs
			var lz: float = d.ladder_z
			var lt: float = _O.t_of(d, lz)
			var hw: float = maxf(_O.half_at(d, lt, 0.0), _O.deck_half(d, lt))
			me.global_position = o + Vector3(hw + 2.5, _D.SWIM_EYE - 1.6, lz)
			me.head.rotation.x = 0.0
			_step = 4
			_t = 0.0
		4:
			if _t < 1.5:
				return false
			if not _D.is_swimming(me.global_position):
				_fail("dropped beside her, he isn't swimming: %s" % str(me.global_position - o))
			me.rotation.y = PI * 0.5 # face the hull
			me.head.rotation.x = deg_to_rad(15.0)
			_step = 5
			_t = 0.0
		5:
			if _t < 0.3:
				return false
			me.ray.force_raycast_update()
			var n: Node = me._interact_target()
			if n == null or not n.has_method("get_prompt") or not "aboard" in str(n.get_prompt(me)).to_lower():
				_fail("swimming by the rungs, he can't take hold of them (%s)" % str(n))
				_step = 7
			else:
				n.interact(me)
				_step = 6
			_t = 0.0
		6:
			if _t < 4.0:
				return false
			var at: Vector3 = me.global_position - o
			if absf(at.y - _O.deck_y(d, _O.t_of(d, at.z))) > 0.5:
				_fail("climbing the rungs didn't bring him up on deck: %s" % str(at))
			_step = 7
		7:
			print("deck walk (%s): %s" % [d.key, "ok" if _bad.is_empty() else str(_bad)])
			quit(1 if not _bad.is_empty() else 0)
			return true
	return false
