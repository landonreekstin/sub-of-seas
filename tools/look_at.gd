extends SceneTree
## Pictures from a few places in a boat: [room type, x, metres in from its fore end, yaw].
##   xvfb-run -a -s "-screen 0 960x540x24" godot --rendering-driver opengl3 --resolution 960x540 --path . -s tools/look_at.gd -- <sub> <out dir> <type,x,dz,yaw_deg> ...

var _game: Node
var _out := "screenshots/look"
var _spots: Array = []
var _frames := 0
const SETTLE := 14


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var net: Node = root.get_node("Net")
	net.sub_key = args[0]
	net.mission = "cw_convoy" if args[0] == "typhoon" else "convoy"
	net.mode = 1
	net.port = 7096
	_out = args[1]
	for a in args.slice(2):
		_spots.append(a.split(","))
	DirAccess.make_dir_recursive_absolute(_out)
	change_scene_to_file.call_deferred("res://game/game.tscn")


func _process(_delta: float) -> bool:
	if _game == null:
		if current_scene != null and current_scene.name == "Game":
			_game = current_scene
		return false
	if _game.interior == null or _game.local_player == null:
		return false
	_frames += 1
	if _frames < 40:
		return false
	var k := (_frames - 40) / SETTLE
	if k >= _spots.size():
		quit(0)
		return true
	var s: PackedStringArray = _spots[k]
	if (_frames - 40) % SETTLE == 0:
		var c: Dictionary = _game.interior.comp(s[0])
		var me: Node3D = _game.local_player
		me.global_position = Vector3(float(c.get("x", 0.0)) + float(s[1]), float(c.get("y", 0.0)) + 0.1, float(c.z0) + float(s[2]))
		me.rotation.y = deg_to_rad(float(s[3]))
	elif (_frames - 40) % SETTLE == SETTLE - 1:
		get_root().get_texture().get_image().save_png("%s/%s_%d.png" % [_out, s[0], k])
	return false
