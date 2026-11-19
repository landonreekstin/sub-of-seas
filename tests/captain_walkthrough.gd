extends SceneTree
## One player alone in the captain's chair (Blaney: "pilot the sub entirely alone by issuing
## commands"): Tab picks a ship the boat knows of and Space has the crew attack it until it sinks;
## then N sends her to the nearest place and the crew take her there by themselves, and 2 takes
## her to periscope depth.
##   godot --headless --path . -s tests/captain_walkthrough.gd -- [<sub>]

var _game: Node
var _t := 0.0
var _step := "enter"
var _sunk0 := 0
var _wait := 0.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var net: Node = root.get_node("Net")
	net.sub_key = args[0] if not args.is_empty() else "gato"
	net.mission = "cw_convoy" if net.sub_key == "typhoon" else "convoy"
	net.mode = 1
	net.port = int(OS.get_environment("TEST_PORT")) if OS.has_environment("TEST_PORT") else 7100 + OS.get_process_id() % 2000 # tests/walkthroughs.sh gives each its own
	Engine.time_scale = 4.0
	change_scene_to_file.call_deferred("res://game/game.tscn")


func _order(key: String, value: Variant = null) -> void:
	_game.apply_order("captain", key, value, _game.multiplayer.get_unique_id())


func _physics_process(delta: float) -> bool:
	if _game == null:
		if current_scene != null and current_scene.name == "Game":
			_game = current_scene
		return false
	var w: Variant = root.get_node("Sim").get("world")
	if w == null or _game.local_player == null:
		return false
	var before := _t
	_t += delta
	if int(_t) != int(before) and int(_t) % 30 == 0:
		print("captain: %3d s %s heading %.0f speed %.1f depth %.0f/%.0f battery %.2f sunk %d %s" % [int(_t), _step, w.sub.heading, w.sub.speed, w.sub.depth,
			w.sub.ordered_depth, w.sub.battery, _game.crew.sunk, _game.crew.result])
	if _game.crew.result != "":
		return _end("FAIL: the patrol ended (%s)" % _game.crew.result)
	match _step:
		"enter":
			if _t > 2.0:
				_game.rq_station_enter("captain")
				_step = "target"
				_sunk0 = _game.crew.sunk
		"target":
			if _game.station_occupant("captain") != _game.multiplayer.get_unique_id():
				return _end("FAIL: couldn't sit in the chair")
			if _t < _wait:
				return false
			_wait = _t + 5.0
			_order("target")
			if int(_game.crew.get("captain_target", -1)) < 0:
				if _t > 900.0:
					return _end("FAIL: never knew of a ship")
				return false
			_order("attack")
			print("captain: attacking at %d s" % int(_t))
			_step = "attack"
		"attack":
			if _game.crew.sunk > _sunk0:
				print("captain: sank one at %d s" % int(_t))
				_order("next_place")
				if _game.crew.get("waypoint", {}).is_empty():
					return _end("FAIL: N set no waypoint")
				print("captain: waypoint %s" % _game.crew.waypoint.name)
				_step = "travel"
			elif _t > 2400.0:
				return _end("FAIL: nothing sunk")
		"travel":
			w.sub.battery = maxf(w.sub.battery, 0.6) # a long way dived: the charge she'd put in on the surface, not this test's job
			if _game.crew.get("waypoint", {}).is_empty():
				print("captain: arrived at %d s" % int(_t))
				_order("preset", "periscope")
				_step = "dive"
				_wait = _t + 3.0
			elif _t > 4000.0:
				return _end("FAIL: never got to the waypoint")
		"dive":
			if _t < _wait:
				return false
			if absf(w.sub.ordered_depth - w.sub.data.periscope_depth) > 1.0:
				return _end("FAIL: 2 didn't order periscope depth (%.0f)" % w.sub.ordered_depth)
			return _end("ok: sank one, went to a place and came to periscope depth, alone in the chair (%d s)" % int(_t))
	return false


func _end(text: String) -> bool:
	print("captain: " + text)
	quit(0 if text.begins_with("ok") else 1)
	return true
