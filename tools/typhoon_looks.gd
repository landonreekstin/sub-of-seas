extends SceneTree
## Close-ups of what the room tour can't see on a Typhoon: signs, cross passages, notebooks, band.
##   godot --path . -s tools/typhoon_looks.gd -- <out dir>

## name, x, y, z, yaw (0 forward, PI aft, PI/2 port, -PI/2 starboard), pitch
const LOOKS := [
	["missile_mid", 0.0, 0.1, -30.0, 0.0, 0.0],
	["sign_missile", 0.0, 0.1, -76.0, 0.0, 0.25],
	["sign_passage", 0.0, 0.1, -10.0, 0.0, 0.25],
	["cross_port_in_missile", 0.0, 0.1, -50.0, PI / 2.0, 0.0],
	["cross_stbd_in_missile", 0.0, 0.1, -50.0, -PI / 2.0, 0.0],
	["cross_seen_from_port_hull", -6.0, 0.1, -50.0, -PI / 2.0, 0.0],
	["cross_in_it", -3.0, 0.1, -7.5, PI / 2.0, 0.0],
	["rec_door", -6.0, 0.1, -7.5, -PI / 2.0, 0.0],
	["berth_door", -6.0, 0.1, -50.0, -PI / 2.0, 0.0],
	["turbine_door", -6.0, 0.1, 45.0, -PI / 2.0, 0.0],
	["steering", 0.0, 0.1, 57.0, 0.0, 0.0],
	["sign_radio", 6.0, 0.1, -9.0, 0.0, 0.25],
	["notebooks", 0.0, 2.9, -3.5, 0.0, -0.2],
	["pa_mic", 0.0, 2.9, -2.0, PI, 0.0],
	["band_room", -6.0, 0.1, -1.0, 0.0, 0.0],
]

var _game: Node
var _out := ""
var _i := -30
var _only := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	if args.size() > 1: # just the looks with this in their name
		_only = args[1]
	var net: Node = root.get_node("Net")
	net.mission = "cw_convoy"
	net.sub_key = "typhoon"
	net.mode = 1
	net.port = 7096
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
	if _i == -15:
		_game.rq_pa("all hands")
	if _i == -2:
		_game.rq_pa("band play")
	if _i < 0:
		return false
	var looks := LOOKS.filter(func(l: Array) -> bool: return _only in str(l[0]))
	var n := _i / 25
	if n >= looks.size():
		quit(0)
		return true
	var look: Array = looks[n]
	var me: Node3D = _game.local_player
	me.global_position = Vector3(look[1], look[2], look[3])
	me.velocity = Vector3.ZERO
	me.rotation.y = look[4]
	me.camera.rotation.x = look[5]
	if _i % 25 == 24:
		get_root().get_texture().get_image().save_png("%s/%s.png" % [_out, look[0]])
	return false
