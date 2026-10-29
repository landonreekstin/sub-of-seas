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
		push_error("walkthrough: stalled on step %d" % i)
		quit(1)
		return false
	_act(i)
	return false


func _once(key: String) -> bool:
	if _did.has(key):
		return false
	_did[key] = true
	return true


func _act(i: int) -> void:
	var g: Variant = _game
	var hull: HullState = _sim.world.hull
	match i:
		0: if _once("a"): g.rq_station_enter("helm")
		1: if _once("a"): g.rq_order("helm", "telegraph", 2)
		2: if _once("a"): g.rq_station_enter("dive")
		3: if _once("a"): g.rq_order("dive", "depth", _sim.world.sub.data.periscope_depth)
		4: if _once("a"): g.rq_station_enter("periscope")
		5: if _once("a"): g.rq_order("periscope", "raised", true)
		6: if _once("a"): g.rq_order("periscope", "ranged", true)
		7: if _once("a"): g.rq_order("periscope", "raised", false)
		8: if _once("a"): g.rq_station_enter("tube_1")
		9:
			if _once("a"):
				g.rq_order("tube_1", "flood", null)
				g.rq_order("tube_1", "door", null)
		10: if _once("a"): g.rq_order("tube_1", "fire", null)
		11: if _once("a"): g.rq_station_enter("sonar")
		12: if _once("a"): g.rq_order("sonar", "classified", true)
		13:
			if _once("a"):
				g.rq_station_enter("dive")
				g.rq_order("dive", "depth", 45.0)
				g.rq_station_enter("helm")
				g.rq_order("helm", "telegraph", 1)
		15:
			if _once("a"):
				g.rq_tool("torch")
			if not hull.leaks.is_empty():
				g.rq_work("torch", str(hull.leaks[0].id), 0.25)
		16:
			if _once("a"):
				g.rq_tool("extinguisher")
			if not hull.fires.is_empty():
				g.rq_work("extinguisher", str(hull.fires[0].id), 0.25)
		17:
			if _once("a"):
				g.rq_tool("pump")
				g.rq_place_pump(Vector3(0, 0, -4))
		18: if _once("a"): g.rq_door("fwd")
