extends SceneTree
## Plays the training patrol start to finish through the same host requests players send.
##   godot --headless --path . -s tests/tutorial_walkthrough.gd
## Exits 0 when the debrief says "training", 1 if a step stalls.

const TIMEOUT := 900.0 ## game seconds
const STALL := 240.0 ## game seconds on one step before giving up

var _game: Node ## game.gd uses autoloads, so it is reached untyped through the scene
var _step := -1
var _step_time := 0.0
var _fired := false
var _did := {}
var _sim: Node ## the Sim autoload (autoload names aren't compile-time identifiers in -s scripts)


func _initialize() -> void:
	var net: Node = root.get_node("Net")
	_sim = root.get_node("Sim")
	net.mission = "training"
	net.mode = 1 # Net.Mode.HOST
	net.port = 7090
	Engine.time_scale = 6.0
	Engine.physics_ticks_per_second = 30
	change_scene_to_file.call_deferred("res://game/game.tscn")


func _process(delta: float) -> bool:
	if _game == null:
		if current_scene != null and current_scene.name == "Game":
			_game = current_scene
		elif Time.get_ticks_msec() > 30000:
			push_error("walkthrough: the patrol never started (port %d in use?)" % root.get_node("Net").port)
			quit(1)
		return false
	if _sim.world == null:
		return false
	var crew: Dictionary = _game.crew
	if crew.result != "":
		print("walkthrough: result=%s after %.0f s" % [crew.result, _sim.world.time])
		quit(0 if crew.result == "training" else 1)
		return false
	var i: int = crew.tutorial.step
	if i != _step:
		print("walkthrough: step %d at %.0f s  %s" % [i, _sim.world.time, _game.tutorial.steps[i].text.substr(0, 60)])
		_step = i
		_step_time = 0.0
		_did.clear()
	_step_time += delta
	if _step_time > STALL or _sim.world.time > TIMEOUT:
		var sub: SubState = _sim.world.sub
		push_error("walkthrough: stalled on step %d (depth %.1f ballast %.2f diesels %s broken %s stations %s)" % [
			i, sub.depth, sub.ballast, sub.diesels, _sim.world.hull.broken.keys(), crew.stations])
		quit(1)
		return false
	_act(i)
	return false


func _once(key: String) -> bool:
	if _did.has(key):
		return false
	_did[key] = true
	return true


## Picks the tool up again whenever it isn't in hand (passing out drops it).
func _hold(tool: String) -> void:
	if _game.crew.tools.get(1, "") != tool and not _game.crew.knocked.has(1):
		_game.rq_tool(tool)


func _act(i: int) -> void:
	var g: Variant = _game
	var hull: HullState = _sim.world.hull
	# Whatever the pattern broke that this step needs gets fixed first, as a player would.
	var needs: String = _game.tutorial.steps[i].get("needs", "")
	if needs != "" and hull.is_broken(needs):
		_hold("wrench")
		g.rq_work("wrench", needs, 0.25)
		return
	match _game.tutorial.steps[i].id:
		"helm": if _once("a"): g.rq_station_enter("helm")
		"ahead": if _once("a"): g.rq_order("helm", "telegraph", 2)
		"ballast": if _once("a"): g.rq_station_enter("ballast")
		"vents": if _once("a"): g.rq_order("ballast", "vent", null)
		"dive": if _once("a"): g.rq_station_enter("dive")
		"depth": if _once("a"): g.rq_order("dive", "depth", _sim.world.sub.data.periscope_depth)
		"scope": if _once("a"): g.rq_station_enter("periscope")
		"raise": if _once("a"): g.rq_order("periscope", "raised", true)
		"range": if _once("a"): g.rq_order("periscope", "ranged", true)
		"mark":
			var marks: Array = _game.crew.tdc.marks
			if marks.is_empty() or _sim.world.time - float(marks[-1].t) >= Tdc.MIN_SPAN + 1.0:
				var target: ShipState = _game.tutorial._target
				var to: Vector2 = target.pos - _sim.world.sub.pos
				g.rq_order("periscope", "mark", [target.id, rad_to_deg(atan2(to.x, to.y)), to.length()])
		"lower": if _once("a"): g.rq_order("periscope", "raised", false)
		"tdc": if _once("a"): g.rq_station_enter("tdc")
		"send": if _once("a"): g.rq_order("tdc", "send", null)
		"tube": if _once("a"): g.rq_station_enter("tube_1")
		"flood":
			if _once("a"):
				g.rq_order("tube_1", "flood", null)
				g.rq_order("tube_1", "door", null)
		"fire": if _once("a"): g.rq_order("tube_1", "fire", null)
		"sonar": if _once("a"): g.rq_station_enter("sonar")
		"classify": if _once("a"): g.rq_order("sonar", "classified", true)
		"deep":
			if _once("a"):
				g.rq_station_enter("dive")
				g.rq_order("dive", "depth", 45.0)
				g.rq_station_enter("helm")
				g.rq_order("helm", "telegraph", 1)
		"weld":
			_hold("torch")
			if not hull.leaks.is_empty():
				g.rq_work("torch", str(hull.leaks[0].id), 0.25)
		"extinguish":
			_hold("extinguisher")
			if not hull.fires.is_empty():
				g.rq_work("extinguisher", str(hull.fires[0].id), 0.25)
		"wrench":
			_hold("wrench")
			g.rq_work("wrench", "helm", 0.25)
		"pump":
			if _once("a"):
				g.rq_tool("pump")
				g.rq_place_pump(Vector3(0, 0, -4))
		"door": if _once("a"): g.rq_door(_game.tutorial.fwd_door())
		"air":
			if _once("a"):
				g.rq_station_enter("air")
				g.rq_order("air", "canister", null)
		"up":
			if _once("a"):
				g.rq_station_enter("dive")
				g.rq_order("dive", "depth", 0.0)
		"blow":
			if _once("a"):
				g.rq_station_enter("ballast")
				g.rq_order("ballast", "blow", null)
		"diesel":
			if _once("a"):
				g.rq_station_enter("engine")
				g.rq_order("engine", "diesel", [0, true])
