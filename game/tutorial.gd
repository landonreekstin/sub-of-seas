class_name Tutorial
extends Node
## The training patrol: a checklist the whole crew works through together, one step at a
## time. The host checks each step against the sim and crew state and advances
## `crew.tutorial.step`; every peer shows the current step and a marker over where to go.
## Scripted parts (an anchored target, a destroyer that runs over the boat and drops one
## pattern) are host-side too.

const FREIGHTER := preload("res://data/ships/freighter.tres")
const DESTROYER := preload("res://data/ships/destroyer.tres")

var game: Game
var steps: Array[Dictionary] = []
var _flags := {} ## things that happened this step ("ranged", "classified", "fired", ...)
var _marker: Label3D
var _target: ShipState
var _destroyer: ShipState
var _pattern_dropped := false
var _pattern_over := false ## the pattern has gone off and the damage is set up
var _entered := -1


func _init(g: Game) -> void:
	game = g
	name = "Tutorial"
	_build_steps()


func _ready() -> void:
	_marker = Label3D.new()
	_marker.text = "▼"
	_marker.font_size = 160
	_marker.pixel_size = 0.004
	_marker.modulate = UiKit.BRASS
	_marker.outline_size = 24
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.visible = false
	game.interior.add_child(_marker)
	Sim.event.connect(_on_sim_event)


func step_index() -> int:
	return game.crew.get("tutorial", {}).get("step", 0)


## Host: the starting situation. Surfaced, stopped, a hulk anchored dead ahead.
func setup_world() -> void:
	var w := Sim.world
	w.dud_chance = 0.0
	w.sub.telegraph = 0
	_target = w.add_ship(FREIGHTER, Vector2(0, 2600), 90.0, 0.0)
	_target.passive = true
	_target.hp = 1.0


## Host: a station reported something only it can see (a stadimeter range, a classification).
func flag(key: String) -> void:
	_flags[key] = true


func _on_sim_event(kind: String, _data: Dictionary) -> void:
	_flags[kind] = true


# --- Steps -----------------------------------------------------------------

func _station(id: String) -> Callable:
	return func() -> Vector3: return game.interior.stations[id].global_position + Vector3(0, 2.3, 0)


func _manned(id: String) -> Callable:
	return func() -> bool: return game.station_occupant(id) != 0


func _build_steps() -> void:
	var sub := func() -> SubState: return Sim.world.sub
	var hull := func() -> HullState: return Sim.world.hull
	steps = [
		{"id": "helm", "text": "Welcome aboard. Man the HELM: starboard side of the control room, forward. Walk up and press E.",
			"marker": _station("helm"), "done": _manned("helm")},
		{"id": "ahead", "needs": "helm", "text": "Ring up AHEAD 2/3 on the engine telegraph: press W twice. Keep the rudder amidships.",
			"marker": _station("helm"), "done": func() -> bool: return sub.call().telegraph >= 2},
		{"id": "ballast", "text": "To dive, first flood the main ballast tanks. Leave the helm (Q) and man the BALLAST manifold: control room, port side, aft.",
			"marker": _station("ballast"), "done": _manned("ballast")},
		{"id": "vents", "needs": "ballast", "text": "Open the vents: press V. The lights go red as the tanks flood and she settles to decks awash.",
			"marker": _station("ballast"), "done": func() -> bool: return sub.call().vents_open},
		{"id": "dive", "text": "Leave the manifold (Q) and man the DIVE station, port side forward.",
			"marker": _station("dive"), "done": _manned("dive")},
		{"id": "depth", "needs": "dive", "text": "Take her down to periscope depth: press 2. Watch the depth gauge.",
			"marker": _station("dive"),
			"done": func() -> bool: return sub.call().depth >= sub.call().data.periscope_depth - 1.0},
		{"id": "scope", "text": "Climb the ladder (E) to the conning tower and man the PERISCOPE.",
			"marker": _station("periscope"), "done": _manned("periscope")},
		{"id": "raise", "needs": "periscope", "text": "Raise the periscope: press R.",
			"marker": _station("periscope"), "done": func() -> bool: return sub.call().periscope_raised},
		{"id": "range", "needs": "periscope", "text": "A freighter lies dead ahead. Put the crosshair on it (mouse, Z zooms) and take a range with the stadimeter: F.",
			"marker": _station("periscope"), "done": func() -> bool: return _flags.has("ranged")},
		{"id": "mark", "needs": "periscope", "text": "Mark him for the TDC: M. Then mark him again after 30 seconds (and again: every mark helps), so the TDC can work out his course and speed. Z (high power) ranges better.",
			"marker": _station("periscope"), "done": func() -> bool:
				var marks: Array = game.crew.tdc.marks
				return marks.size() >= 2 and float(marks[-1].t) - float(marks[0].t) >= Tdc.MIN_SPAN},
		{"id": "lower", "needs": "periscope", "text": "Good. Lower the scope (R): a raised scope is how lookouts spot you.",
			"marker": _station("periscope"), "done": func() -> bool: return not sub.call().periscope_raised},
		{"id": "tdc", "text": "Man the TDC: the cabinet beside the periscope, starboard side.",
			"marker": _station("tdc"), "done": _manned("tdc")},
		{"id": "send", "needs": "tdc", "text": "The TDC has his course and speed, and the gyro angle to hit him. Send it to the tubes: T. Their gyros now follow it.",
			"marker": _station("tdc"), "done": func() -> bool: return game.crew.tdc.follow},
		{"id": "tube", "text": "Go forward through officers' country to the FORWARD TORPEDO ROOM and man TUBE 1, top right.",
			"marker": _station("tube_1"), "done": _manned("tube_1")},
		{"id": "flood", "needs": "tube_1", "text": "Flood the tube (F), then open the outer door (O).",
			"marker": _station("tube_1"), "done": func() -> bool:
				var t: Dictionary = game.crew.tubes[0]
				return t.flooded and t.door},
		{"id": "fire", "needs": "tube_1", "text": "The gyro follows the TDC. FIRE: Space. Then wait for the hit.",
			"marker": _station("tube_1"), "done": func() -> bool: return game.crew.sunk >= 1,
			"hint": _miss_hint},
		{"id": "sonar", "text": "Fast screws to the north: an escort! Man the SONAR (control room, port side aft).",
			"marker": _station("sonar"), "done": _manned("sonar"), "enter": _spawn_destroyer},
		{"id": "classify", "needs": "sonar", "text": "Train the hydrophone (A/D or mouse) onto the loudest contact until it reads WARSHIP.",
			"marker": _station("sonar"), "done": func() -> bool: return _flags.has("classified")},
		{"id": "deep", "needs": "dive", "text": "He's coming for us. Go deep: DIVE station, press 3 (45 m). And slow to AHEAD 1/3 at the helm (S).",
			"marker": _station("dive"), "done": func() -> bool:
				return sub.call().depth >= 40.0 and sub.call().telegraph <= 1},
		{"id": "run_in", "text": "Hold depth and keep quiet... Here he comes at 30 knots. Listen on the sonar if you like. Brace for depth charges!",
			"marker": Callable(), "enter": _run_over, "done": func() -> bool: return _pattern_over},
		{"id": "weld", "text": "LEAK! Take a WELDING TORCH from the DAMAGE CONTROL rack (E), then hold LMB on the leak.",
			"marker": _first_spot.bind("leak"), "done": func() -> bool: return hull.call().leaks.is_empty()},
		{"id": "extinguish", "text": "FIRE! Swap for the EXTINGUISHER at the rack and hold LMB on the flames. Smoke fouls the air: thick enough, it knocks you out.",
			"marker": _first_spot.bind("fire"), "done": func() -> bool: return hull.call().fires.is_empty()},
		{"id": "wrench", "text": "The pattern knocked out the HELM. Take a WRENCH from the rack and hold LMB on the helm until it's fixed.",
			"marker": _station("helm"), "done": func() -> bool: return not hull.call().is_broken("helm")},
		{"id": "pump", "text": "Pump out the water: take the PORTABLE PUMP from the rack and set it down (LMB) in the wet compartment.",
			"marker": _rack, "done": func() -> bool: return not hull.call().pumps.is_empty()},
		{"id": "door", "text": "Shut a WATERTIGHT DOOR (E on the door). Shut doors stop water, fire and smoke spreading.",
			"marker": func() -> Vector3: return game.interior.doors[fwd_door()].global_position + Vector3(0, 2.3, 0),
			"done": func() -> bool: return game.crew.doors.values().has(false)},
		{"id": "air", "needs": "air", "text": "Down here the crew's breath fouls the air. Go aft to the AIR panel (engine room, starboard) and load a fresh CO2 canister: C.",
			"marker": _station("air"), "done": func() -> bool: return Sim.world.air.canister_left > 0.0},
		{"id": "up", "needs": "dive", "text": "He's lost us. Bring her up: DIVE station, press 1. The planes take her up to decks awash.",
			"marker": _station("dive"), "done": func() -> bool: return sub.call().depth <= SubState.AWASH_DEPTH + 0.5},
		{"id": "blow", "needs": "ballast", "text": "Now blow the tanks dry to surface: BALLAST manifold, B.",
			"marker": _station("ballast"), "done": func() -> bool: return sub.call().is_surfaced()},
		{"id": "diesel", "needs": "engine", "text": "Surfaced. Charge the battery: man the DIESEL CONTROLS (engine room, aft end) and start a diesel: 1. Stop them again before you ever dive.",
			"marker": _station("engine"), "done": func() -> bool: return sub.call().diesels.any(func(d: float) -> bool: return d > 0.0)},
	]


## The door in the control room's forward bulkhead.
func fwd_door() -> String:
	return "d%d" % (game.interior.comp_index("control") - 1)


func step_number(id: String) -> int:
	for i in steps.size():
		if steps[i].id == id:
			return i
	return -1


func _first_spot(kind: String) -> Vector3:
	var hull := Sim.world.hull
	var list: Array = hull.leaks if kind == "leak" else hull.fires
	if list.is_empty():
		return Vector3.INF
	return list[0].p + Vector3(0, 1.2, 0)


func _rack() -> Vector3:
	return game.interior.racks["control"]


func _miss_hint() -> String:
	var w := Sim.world # runs on every peer: use replicated state only
	var afloat := w.ships.any(func(s: ShipState) -> bool: return not s.data.asw and not s.is_sinking())
	if game.crew.tubes[0].loaded or not w.torpedoes.is_empty() or not afloat or game.crew.sunk > 0:
		return ""
	return "Missed! Reload: close the outer door (O), drain (F), then L and stay at the tube 30 s. Steer the bow onto the target first."


## Host: an escort appears to the north and steams straight for the boat.
func _spawn_destroyer() -> void:
	var sub := Sim.world.sub
	_destroyer = Sim.world.add_ship(DESTROYER, sub.pos + Vector2(400, 2500), 180.0, 16.0)
	_destroyer.ai = null # scripted, not hunting
	_destroyer.passive = true
	_aim_destroyer()


func _aim_destroyer() -> void:
	if _destroyer == null:
		return
	_destroyer.course = ShipState.bearing(_destroyer.pos, Sim.world.sub.pos)


func _run_over() -> void:
	# Nobody can see him from down here: bring him within a minute's run so the wait stays tense, not dull.
	var sub := Sim.world.sub
	if _destroyer.pos.distance_to(sub.pos) > 900.0:
		_destroyer.pos = sub.pos + (_destroyer.pos - sub.pos).normalized() * 900.0
	_destroyer.speed = maxf(_destroyer.speed, 20.0 * SubState.KNOT)
	_destroyer.ordered_speed = 30.0 * SubState.KNOT


func _drop_pattern() -> void:
	_pattern_dropped = true
	var w := Sim.world
	var sub := w.sub
	Sim.world.event.emit("splash", {"ship": _destroyer.id, "x": _destroyer.pos.x, "y": _destroyer.pos.y})
	# Close enough to hurt, set a little shallow (they usually were).
	for off: Vector2 in [Vector2(14, 20), Vector2(-18, -10), Vector2(30, -30), Vector2(-40, 35)]:
		w.drop_charge(sub.pos + off, sub.depth - 12.0)


## Host, after the pattern: make sure there is one of each job to practise on.
func _ensure_damage() -> void:
	var hull := Sim.world.hull
	var cr := game.interior.comp_index("control")
	if hull.leaks.is_empty():
		hull.add_leak(cr, 1, Sim.world.rng, 1.0)
	if hull.fires.is_empty():
		hull.add_fire(cr, Sim.world.rng)
	hull.broken["helm"] = HullState.WRENCH_SECONDS
	hull.comps[cr].water = maxf(hull.comps[cr].water, 0.08)


func _process(_delta: float) -> void:
	var i := step_index()
	_update_marker(i)
	_update_hud(i)
	if not multiplayer.is_server() or game.crew.result != "" or i >= steps.size():
		return
	if i != _entered:
		_entered = i
		var enter: Variant = steps[i].get("enter")
		if enter is Callable and (enter as Callable).is_valid():
			enter.call()
	_script_tick(i)
	if steps[i].done.call():
		_advance(i)


func _script_tick(_i: int) -> void:
	if _destroyer == null or _destroyer.is_sinking():
		return
	var d := _destroyer.pos.distance_to(Sim.world.sub.pos)
	if not _pattern_dropped:
		var running_in := step_index() >= step_number("run_in")
		if running_in and d < 80.0:
			_drop_pattern() # right overhead
		elif d > 300.0 or running_in:
			_aim_destroyer()
		else:
			_destroyer.ordered_speed = 4.0 * SubState.KNOT # circles back until the crew is deep
			_destroyer.course = fposmod(_destroyer.course + 0.5, 360.0)
	elif not _pattern_over and Sim.world.charges.is_empty():
		_pattern_over = true
		_ensure_damage()
		_destroyer.course = fposmod(_destroyer.heading + 20.0, 360.0) # runs on and loses us
		_destroyer.ordered_speed = 18.0 * SubState.KNOT


func _advance(i: int) -> void:
	_flags.clear() # what happens from here on counts for the next step
	game.crew.tutorial.step = i + 1
	if i + 1 >= steps.size():
		game.end_patrol("training", "Training complete. You ran the whole boat: helm, ballast, dive, scope, TDC, tubes, sonar, damage control, air and the diesels.")
	else:
		game.announce.rpc("✓  Step %d done." % (i + 1))
	game.push_crew()


func _update_marker(i: int) -> void:
	_marker.visible = false
	if i >= steps.size() or game.crew.result != "":
		return
	var m: Variant = steps[i].get("marker")
	if not (m is Callable) or not (m as Callable).is_valid():
		return
	var p: Vector3 = m.call()
	if p == Vector3.INF:
		return
	_marker.position = p + Vector3(0, 0.12 * sin(Time.get_ticks_msec() * 0.006), 0)
	_marker.visible = true


func _update_hud(i: int) -> void:
	if game.crew.result != "":
		game.hud.set_objective("", "")
		return
	if i >= steps.size():
		return
	var text: String = steps[i].text
	var needs: String = steps[i].get("needs", "")
	if needs != "" and Sim.world.hull.is_broken(needs):
		var st: Station = game.interior.stations[needs]
		text += "\n\nThe %s is BROKEN. Fix it first: a WRENCH from a damage control rack, hold LMB on it." % st.display_name.to_lower()
	var hint: Variant = steps[i].get("hint")
	if hint is Callable:
		var h: String = hint.call()
		if h != "":
			text += "\n\n" + h
	game.hud.set_objective("TRAINING  %d / %d" % [i + 1, steps.size()], text)
