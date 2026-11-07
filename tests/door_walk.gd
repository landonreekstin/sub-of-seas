extends SceneTree
## A real player walks through every door of a boat, both ways, and up to the middle of each
## room's neighbour: nothing may stand in a doorway.
##   godot --headless --path . -s tests/door_walk.gd -- <sub>

var _game: Node
var _left: Array = []
var _here: Dictionary
var _t := -1.0
var _bad: Array[String] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var net: Node = root.get_node("Net")
	var sub: String = args[0] if not args.is_empty() else "typhoon"
	net.mission = "cw_convoy" if sub == "typhoon" else "convoy"
	net.sub_key = sub
	net.mode = 1
	net.port = int(OS.get_environment("TEST_PORT")) if OS.has_environment("TEST_PORT") else 7100 + OS.get_process_id() % 2000 # tests/walkthroughs.sh gives each its own
	Engine.time_scale = 4.0
	change_scene_to_file.call_deferred("res://game/game.tscn")


func _physics_process(delta: float) -> bool:
	if _game == null:
		if current_scene != null and current_scene.name == "Game":
			_game = current_scene
		return false
	var i: Variant = _game.interior
	var me: Variant = _game.local_player
	if i == null or me == null or root.get_node("Sim").get("world") == null:
		return false
	if _left.is_empty() and _here.is_empty():
		for id: String in i.doors:
			var at: Vector3 = i.doors[id].global_position
			if id.begins_with("x"): # right across, from the middle of the centre room to the middle of the hull
				var hull := signf(at.x) * 6.0
				_left.append({"id": id, "from": Vector3(0.0, at.y, at.z), "to": Vector3(hull, at.y, at.z)})
				_left.append({"id": id, "from": Vector3(hull, at.y, at.z), "to": Vector3(0.0, at.y, at.z)})
			else:
				_left.append({"id": id, "from": at + Vector3(0, 0, -1.6), "to": at + Vector3(0, 0, 1.6)})
				_left.append({"id": id, "from": at + Vector3(0, 0, 1.6), "to": at + Vector3(0, 0, -1.6)})
		print("walking %d doors, both ways" % i.doors.size())
	if _t < 0.0:
		if _left.is_empty():
			print("blocked: %s" % str(_bad) if not _bad.is_empty() else "ok: every door walks clear")
			Input.action_release("move_forward")
			quit(1 if not _bad.is_empty() else 0)
			return true
		_here = _left.pop_back()
		me.global_position = _here.from + Vector3(0, 0.1, 0)
		me.velocity = Vector3.ZERO
		var way: Vector3 = _here.to - _here.from
		me.rotation.y = atan2(-way.x, -way.z)
		Input.action_press("move_forward")
		_t = 0.0
		return false
	_t += delta
	if Vector2(me.global_position.x, me.global_position.z).distance_to(Vector2(_here.to.x, _here.to.z)) < 0.5:
		_t = -1.0
	elif _t > 5.0:
		_bad.append("%s to %s stuck at %s" % [_here.id, str(_here.to), str(me.global_position)])
		_t = -1.0
	return false
