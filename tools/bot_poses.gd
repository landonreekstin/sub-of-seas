extends SceneTree
## A picture of a bot crewman at every station of a boat, seen from behind his shoulder, to check
## he stands (or sits) naturally at the gear.
##   godot --path . -s tools/bot_poses.gd -- <sub> <out dir> [<only stations with this in the id>]

var _game: Node
var _out := ""
var _only := ""
var _i := -40
var _cam: Camera3D
var _ids: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var net: Node = root.get_node("Net")
	net.sub_key = args[0]
	net.mission = "cw_convoy" if args[0] == "typhoon" else "convoy"
	_out = args[1]
	if args.size() > 2:
		_only = args[2]
	net.mode = 1
	net.port = 7097
	DirAccess.make_dir_recursive_absolute(_out)
	change_scene_to_file.call_deferred("res://game/game.tscn")


func _process(_delta: float) -> bool:
	if _game == null:
		if current_scene != null and current_scene.name == "Game":
			_game = current_scene
		return false
	if _game.interior == null or _game.local_player == null:
		return false
	_i += 1
	if _i == -30:
		for sid: String in _game.interior.stations:
			if _only == "" or _only in sid:
				_game.bot_crew.request(sid, "post", null)
	if _i < 0:
		return false
	if _ids.is_empty():
		_ids = _game.interior._bot_views.keys()
		print("poses: ", _ids, " bots ", _game.crew.get("bots", {}).keys())
		_cam = Camera3D.new()
		_game.add_child(_cam)
		_cam.fov = 70.0
	var n := _i / 12
	if n >= _ids.size():
		quit(0)
		return true
	var v: Node3D = _game.interior._bot_views[_ids[n]]
	var back := v.global_transform.basis.z # behind him: he faces -Z
	var side := v.global_transform.basis.x
	_cam.global_position = v.global_position + back * 1.5 + side * 0.7 + Vector3(0, 1.75, 0)
	_cam.look_at(v.global_position + Vector3(0, 1.1, 0) - back * 0.4)
	_cam.make_current()
	_game.local_player.global_position = v.global_position + back * 1.2 # so a Typhoon draws his room
	if _i % 12 == 11:
		get_root().get_texture().get_image().save_png("%s/%s.png" % [_out, _ids[n]])
	return false
