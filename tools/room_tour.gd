extends SceneTree
## Walks a boat with a camera: a picture of every room looking forward and aft, and how fast it
## draws there. Needs a screen (xvfb-run is fine):
##   godot --rendering-driver opengl3 --resolution 960x540 --path . -s tools/room_tour.gd -- <sub> <out dir> [--all-hands] [--band] [--no-shots]

var _game: Node
var _sim: Node
var _out := "screenshots/tour"
var _all_hands := false
var _band := false
var _shots := true
var _stops: Array = []
var _stage := 0
var _frames := 0
var _rows: Array = []
var _since := 0
const SETTLE := 20 ## frames for a new view to draw before its picture
const TIMED := 40 ## frames timed by the clock (the engine's own delta is capped)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var net: Node = root.get_node("Net")
	_sim = root.get_node("Sim")
	var sub: String = args[0] if args.size() > 0 else "typhoon"
	_out = args[1] if args.size() > 1 else _out
	_all_hands = args.has("--all-hands")
	_band = args.has("--band")
	_shots = not args.has("--no-shots")
	net.mission = "cw_convoy" if sub == "typhoon" else "convoy"
	net.sub_key = sub
	net.mode = 1
	net.port = 7095
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	change_scene_to_file.call_deferred("res://game/game.tscn")


func _process(_delta: float) -> bool:
	if _game == null:
		if current_scene != null and current_scene.name == "Game":
			_game = current_scene
		return false
	if _game.interior == null or _game.local_player == null:
		return false
	match _stage:
		0:
			_frames += 1
			if _frames < 60:
				return false
			if _all_hands:
				_game.rq_pa("all hands")
			if _band:
				_game.rq_pa("band play")
			for c: Dictionary in _game.interior.compartments:
				_stops.append(c)
			_stage = 1
			_frames = 0
		1:
			if _stops.is_empty():
				_finish()
				return true
			var c: Dictionary = _stops[0]
			if _frames == 0:
				_place(c, 0.0)
			_frames += 1
			if _frames == SETTLE and _shots:
				_save(c, "fore")
			if _frames == SETTLE + 1:
				_place(c, PI)
			if _frames == SETTLE * 2:
				_since = Time.get_ticks_usec()
			if _frames == SETTLE * 2 + TIMED:
				var fps := TIMED * 1000000.0 / maxf(Time.get_ticks_usec() - _since, 1.0)
				var row := "%-30s %6.1f fps  cpu %5.2f gpu %5.2f ms  %5d draws  %8d tris  %5d objs" % [c.name, fps,
					RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),
					RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),
					Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
					Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
					Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)]
				_rows.append(row)
				print(row)
				if _shots:
					_save(c, "aft")
				_stops.pop_front()
				_frames = 0
	return false


func _place(c: Dictionary, yaw: float) -> void:
	var me: Node3D = _game.local_player
	var mid := float(c.z1) - 1.2 if yaw == 0.0 else float(c.z0) + 1.2
	me.global_position = Vector3(c.get("x", 0.0), float(c.get("y", 0.0)) + 0.1, mid)
	me.rotation.y = yaw


func _save(c: Dictionary, way: String) -> void:
	get_root().get_texture().get_image().save_png("%s/%s_%s.png" % [_out, c.type, way])


func _finish() -> void:
	print("objects %d, nodes %d, physics %.1f ms, process %.1f ms" % [
		Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	_rows.append("frame's script time: process %.1f ms, physics %.1f ms, nodes %d" % [
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	var f := FileAccess.open(_out + "/results.txt", FileAccess.WRITE) # a detached run has no stdout
	f.store_string("\n".join(_rows) + "\n")
	f.close()
	quit(0)
