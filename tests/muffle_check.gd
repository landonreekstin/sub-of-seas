extends SceneTree
## Shut doors muffle the engines: from the control room the diesels are clear with every door
## open and dull, capped quieter, with them shut.
##   godot --headless --path . -s tests/muffle_check.gd -- <sub>

var _game: Node
var _t := 0.0
var _bad := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var net: Node = root.get_node("Net")
	net.sub_key = args[0] if not args.is_empty() else "gato"
	net.mission = "cw_convoy" if net.sub_key == "typhoon" else "convoy"
	net.mode = 1
	net.port = 7100 + OS.get_process_id() % 2000 # its own port, so tests can run side by side
	change_scene_to_file.call_deferred("res://game/game.tscn")


func _process(delta: float) -> bool:
	if _game == null:
		if current_scene != null and current_scene.name == "Game":
			_game = current_scene
		return false
	var i: Variant = _game.interior
	if i == null or _game.local_player == null or root.get_node("Sim").get("world") == null:
		return false
	_t += delta
	var doors: Dictionary = _game.crew.doors
	var engine: AudioStreamPlayer3D = i.get("_diesel_sound") if i.get("_diesel_sound") != null else i.get("_motor_sound")
	if _t < 1.0:
		_game.local_player.global_position = Vector3(0, 0.1, -3.0)
		for id: String in doors:
			doors[id] = true
		return false
	if _t < 1.5:
		if not doors.values().has(false):
			_bad = engine.bus != &"Effects"
			print("doors open: %s, max %.0f dB" % [engine.bus, engine.max_db])
		for id: String in doors:
			doors[id] = false
		return false
	if _t < 2.0:
		return false
	print("doors shut: %s, max %.0f dB" % [engine.bus, engine.max_db])
	_bad = _bad or engine.bus != &"Muffled" or engine.max_db > -12.0
	print("FAIL" if _bad else "ok: shut doors muffle the engines")
	quit(1 if _bad else 0)
	return true
