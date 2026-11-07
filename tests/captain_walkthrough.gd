extends SceneTree
## One player alone in the captain's chair (Blaney: "pilot the sub entirely alone by issuing
## commands"): N sends her to the nearest place, 1 surfaces her for the trip, the crew take her
## there, 2 takes her to
## periscope depth, Tab picks a ship and Space has the crew attack it, until it sinks.
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
	net.mission = "cw_sandbox" if net.sub_key == "typhoon" else "sandbox"
	net.mode = 1
	net.port = 7100 + OS.get_process_id() % 800
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
	if int(_t) != int(before) and int(_t) % 20 == 0:
		print("captain: %3d s %s pos %s heading %.0f speed %.1f tel %d depth %.0f/%.0f sunk %d batt %.2f result %s diesels %s bots %s" % [int(_t), _step, w.sub.pos.round(), w.sub.heading, w.sub.speed, w.sub.telegraph, w.sub.depth, w.sub.ordered_depth, _game.crew.sunk, w.sub.battery, _game.crew.result, w.sub.diesels, _game.crew.get("bots", {}).keys()])
	match _step:
		"enter":
			if _t > 2.0:
				_game.rq_station_enter("captain")
				_step = "waypoint"
		"waypoint":
			if _game.station_occupant("captain") != _game.multiplayer.get_unique_id():
				return _end("FAIL: couldn't sit in the chair")
			_order("next_place")
			if _game.crew.get("waypoint", {}).is_empty():
				return _end("FAIL: N set no waypoint")
			print("captain: waypoint %s" % _game.crew.waypoint.name)
			_order("preset", "surface") # a long way on the battery would run her flat: up on the diesels
			_step = "travel"
		"travel":
			if _game.crew.get("waypoint", {}).is_empty():
				print("captain: arrived at %d s" % int(_t))
				_order("preset", "periscope")
				_step = "dive"
				_wait = _t + 3.0
			elif _t > 900.0:
				return _end("FAIL: never got to the waypoint")
		"dive":
			if _t < _wait:
				return false
			if absf(w.sub.ordered_depth - w.sub.data.periscope_depth) > 1.0:
				return _end("FAIL: 2 didn't order periscope depth (%.0f)" % w.sub.ordered_depth)
			_sunk0 = _game.crew.sunk
			_step = "target"
		"target":
			_order("scope")
			_order("target")
			if int(_game.crew.get("captain_target", -1)) < 0:
				# nothing known yet: steer for the nearest ship until sonar has her
				var best: Variant = null
				for s in w.ships:
					if best == null or s.pos.distance_to(w.sub.pos) < best.pos.distance_to(w.sub.pos):
						best = s
				_game.crew.get_or_add("wants", {})
				var err := wrapf(ShipState.bearing(w.sub.pos, best.pos) - float(_game.crew.wants.get("course", w.sub.heading)), -180.0, 180.0)
				_order("course", clampf(roundf(err / 10.0) * 10.0, -40.0, 40.0))
				if _game.crew.wants.get("speed", 0) < 4:
					_order("speed", 1)
				if _t > 1500.0:
					return _end("FAIL: never heard a ship")
				return false
			_order("attack")
			_step = "attack"
		"attack":
			if _game.crew.sunk > _sunk0:
				return _end("ok: sank one at %d s, alone in the chair" % int(_t))
			if _t > 2400.0:
				return _end("FAIL: nothing sunk")
	return false


func _end(text: String) -> bool:
	print("captain: " + text)
	quit(0 if text.begins_with("ok") else 1)
	return true
