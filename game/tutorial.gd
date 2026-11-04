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
var _called := -1 ## the last step whose crew call this peer has shown
var course := "full"

## The training courses, in menu order: one per crew job, then the whole boat.
const COURSES := {
	"helm": "Helm & dive", "scope": "Periscope & TDC", "torpedo": "Torpedoes", "sonar": "Sonar",
	"damage": "Damage control", "engine": "Engine & air", "full": "Whole boat (long)",
	"attack": "Attack team", "control": "Control room", "party": "Damage party",
}
const BLURBS := {
	"helm": "Steer, ring up speed, and take her down and back up on the planes.",
	"scope": "Raise the scope, range a target, and aim: in Arcade point the bow at its mark; in Standard and Realistic mark it and give the TDC a solution.",
	"torpedo": "Flood, open the door, fire, and reload a torpedo tube.",
	"sonar": "Find a contact on the hydrophone, tell a warship by its screws, plot its bearing.",
	"damage": "After a pattern of depth charges: weld a leak, put out a fire, fix gear, pump, shut doors.",
	"engine": "Run the diesels to charge the battery, stop them to dive, and keep the air clean.",
	"full": "Every station in one patrol, about 28 steps. Best done together as a crew.",
	"attack": "Periscope and torpedoes: one finds and aims at the target, the other floods and fires on the call.",
	"control": "Helm, planes and sonar: sonar finds the escort, the helm and planes get the boat away from it.",
	"party": "Damage control, engine and air: run the diesels, dive, then patch up the boat after a pattern.",
}
## The crew courses (Blaney: taken together, real crewmates giving the calls): which jobs each has.
const CREW_JOBS := {
	"attack": ["scope", "torpedo"], "control": ["helm", "dive", "sonar"], "party": ["damage", "engine"],
}
## A job belongs to whoever mans one of its stations; one with none goes to a free crewman.
const JOBS := {
	"scope": {"name": "periscope", "stations": ["periscope", "tdc"]},
	"torpedo": {"name": "torpedoes", "stations": ["tube_1"]},
	"helm": {"name": "helm", "stations": ["helm"]},
	"dive": {"name": "planes", "stations": ["dive", "ballast"]},
	"sonar": {"name": "sonar", "stations": ["sonar"]},
	"damage": {"name": "damage control", "stations": []},
	"engine": {"name": "engine & air", "stations": ["engine", "air"]},
}
const FULL_LENGTH := 29 ## the first 29 steps in the library are the whole-boat course


func _init(g: Game) -> void:
	game = g
	name = "Tutorial"
	course = str(g.crew.get("tutorial", {}).get("course", "full"))
	if not COURSES.has(course):
		course = "full"
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
	_setup_course()


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
	var list: Array[Dictionary] = [
		{"id": "helm", "at": "helm", "text": "Welcome aboard. Man the HELM: starboard side of the control room, forward. Walk up and press E.",
			"marker": _station("helm"), "done": _manned("helm")},
		{"id": "ahead", "needs": "helm", "text": "Ring up AHEAD 2/3 on the engine telegraph: press W twice. Keep the rudder amidships.",
			"marker": _station("helm"), "done": func() -> bool: return sub.call().telegraph >= 2},
		{"id": "ballast", "at": "ballast", "text": "To dive, first flood the main ballast tanks. Man the BALLAST manifold: control room, port side, aft.",
			"marker": _station("ballast"), "done": _manned("ballast")},
		{"id": "vents", "needs": "ballast", "text": "Open the vents: press V. The lights go red as the tanks flood and she settles to decks awash.",
			"marker": _station("ballast"), "done": func() -> bool: return sub.call().vents_open},
		{"id": "dive", "at": "dive", "text": "Man the DIVE station, port side forward.",
			"marker": _station("dive"), "done": _manned("dive")},
		{"id": "depth", "needs": "dive", "text": "Take her down to periscope depth: press 2. Watch the depth gauge.",
			"marker": _station("dive"),
			"done": func() -> bool: return sub.call().depth >= sub.call().data.periscope_depth - 1.0},
		{"id": "scope", "at": "periscope", "text": "Climb the ladder (E) to the conning tower and man the PERISCOPE.",
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
		{"id": "tdc", "at": "tdc", "text": "Man the TDC: the cabinet beside the periscope, starboard side.",
			"marker": _station("tdc"), "done": _manned("tdc")},
		{"id": "send", "needs": "tdc", "text": "The TDC has his course and speed, and the gyro angle to hit him. Send it to the tubes: T. Their gyros now follow it.",
			"marker": _station("tdc"), "done": func() -> bool: return game.crew.tdc.follow},
		{"id": "tube", "at": "tube_1", "text": "Go forward through officers' country to the FORWARD TORPEDO ROOM and man TUBE 1, top right.",
			"marker": _station("tube_1"), "done": _manned("tube_1")},
		{"id": "flood", "needs": "tube_1", "text": "Flood the tube (F), then open the outer door (O).",
			"marker": _station("tube_1"), "done": func() -> bool:
				var t: Dictionary = game.crew.tubes[0]
				return t.flooded and t.door},
		{"id": "fire", "needs": "tube_1", "text": "The gyro follows the TDC. FIRE: Space. Then wait for the hit.",
			"marker": _station("tube_1"), "done": func() -> bool: return game.crew.sunk >= 1,
			"hint": _miss_hint},
		{"id": "sonar", "at": "sonar", "text": "Fast screws to the north: an escort! Man the SONAR (control room, port side aft).",
			"marker": _station("sonar"), "done": _manned("sonar"), "enter": _spawn_destroyer},
		{"id": "classify", "needs": "sonar", "text": "Train the hydrophone (A/D or mouse) onto the loudest contact until it reads WARSHIP.",
			"marker": _station("sonar"), "done": func() -> bool: return _flags.has("classified")},
		{"id": "deep", "needs": "dive", "ok": ["helm"], "text": "He's coming for us. Go deep: DIVE station, press 3 (45 m). And slow to AHEAD 1/3 at the helm (S).",
			"marker": _station("dive"), "done": func() -> bool:
				return sub.call().depth >= 40.0 and sub.call().telegraph <= 1},
		{"id": "run_in", "ok": ["any"], "text": "Hold depth and keep quiet... Here he comes at 30 knots. Listen on the sonar if you like. Brace for depth charges!",
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
		# Arcade's in place of mark, tdc and send (no TDC in Arcade: point the bow).
		{"id": "aim", "needs": "periscope", "text": "In Arcade torpedoes run straight out of the bow. The red AIM mark over him is where the bow must point (it leads a moving ship); the brass BOW tick is where she points now. Turn her until BOW sits under AIM: it goes green and reads FIRE!",
			"marker": _station("periscope"), "done": func() -> bool: return Sim.world.arcade_solution().ok},
		# Steps only the short per-job courses use.
		{"id": "come_090", "needs": "helm", "text": "Hold D for right rudder and watch the HEADING. Ease back (A) as it nears 090.",
			"marker": _station("helm"), "done": func() -> bool: return absf(wrapf(sub.call().heading - 90.0, -180.0, 180.0)) < 6.0},
		{"id": "steady", "needs": "helm", "text": "Rudder AMIDSHIPS (A or D back to the middle) and hold her on 090.",
			"marker": _station("helm"), "done": func() -> bool:
				return sub.call().rudder == 0 and absf(wrapf(sub.call().heading - 90.0, -180.0, 180.0)) < 10.0},
		{"id": "deep_dive", "needs": "dive", "text": "Press 3: the planes take her down to 45 m. Watch the depth gauge.",
			"marker": _station("dive"), "done": func() -> bool: return sub.call().depth >= 40.0},
		{"id": "back_up", "needs": "dive", "text": "Press 2: back up to periscope depth.",
			"marker": _station("dive"), "done": func() -> bool: return sub.call().depth <= sub.call().data.periscope_depth + 1.5},
		{"id": "reload", "needs": "tube_1", "text": "Shut the outer door (O), drain the tube (F), then reload: L. Stay at the tube until it reads LOADED.",
			"marker": _station("tube_1"), "done": func() -> bool: return game.crew.tubes[0].loaded},
		{"id": "plot", "needs": "sonar", "text": "Keep the hydrophone on him and press M: his bearing goes on the chart for the captain.",
			"marker": _station("sonar"), "done": func() -> bool: return not game.crew.plot.is_empty()},
		{"id": "brace", "ok": ["any"], "text": "Hold on to something. The pattern is on its way down...",
			"marker": Callable(), "enter": _drop_pattern, "done": func() -> bool: return _pattern_over},
		{"id": "diesel_stop", "needs": "engine", "text": "Stop every running diesel: 2. Diesels running when she dives flood the engine room.",
			"marker": _station("engine"), "done": func() -> bool: return sub.call().diesels.all(func(d: float) -> bool: return d <= 0.0)},
		{"id": "under", "ok": ["any"], "text": "Diving: the vents are open and she's going down to 30 m. Hold on.",
			"marker": Callable(), "enter": _dive_to_pattern, "done": func() -> bool: return sub.call().depth >= 25.0},
	]
	var by_id := {}
	for st in list:
		by_id[st.id] = st
	var plan := _plan(course)
	if plan.is_empty(): # the whole boat: the original long checklist, in order
		for st in list.slice(0, FULL_LENGTH):
			plan.append([st.id])
	if game.arcade_aim():
		var arcade := []
		for entry: Array in plan:
			match entry[0]:
				"mark":
					var aim := ["aim", "Captain", "Where do I point her?"] if entry.size() >= 3 and entry[1] != "" else ["aim", "", ""]
					arcade.append(aim + ([entry[-1]] if entry[-1] is Dictionary else []))
				"tdc", "send": pass
				_: arcade.append(entry)
		plan = arcade
	for entry: Array in plan:
		var st: Dictionary = by_id[entry[0]].duplicate()
		if game.arcade_aim() and st.id == "fire":
			st.text = "She's pointed at him and torpedoes run straight out of the bow. FIRE: Space. Then wait for the hit."
		if game.arcade_aim() and entry.size() >= 3 and str(entry[2]).contains("gyro zero"):
			entry = [entry[0], entry[1], str(entry[2]).replace(", gyro zero", "")] + entry.slice(3)
		if entry.size() >= 3:
			st.who = entry[1]
			st.say = entry[2]
		if entry.size() >= 4 and entry[3] is Callable:
			st.enter = entry[3]
		if entry[-1] is Dictionary:
			st.merge(entry[-1], true) # job: who works this step; from: whose job gives the call
		steps.append(st)


## A short course: [step id] or [step id, who calls it, the call, optional enter]. Empty for
## the whole boat. The calls stand in for the crewmates you would hear on a full boat.
func _plan(key: String) -> Array:
	match key:
		"helm": return [
			["helm", "Captain", "Helmsman, man the helm."],
			["ahead", "Captain", "All ahead two-thirds."],
			["come_090", "Captain", "Right full rudder. Come to course zero-niner-zero."],
			["steady", "Captain", "Rudder amidships. Steady as she goes."],
			["dive", "Chief of the boat", "Vents open, she's flooding down. Diving officer, take the planes!", _open_vents],
			["depth", "Captain", "Make your depth periscope depth."],
			["deep_dive", "Captain", "Escort closing! Take her down to 45 metres."],
			["back_up", "Captain", "He's lost us. Bring her back to periscope depth."]]
		"scope": return [
			["scope", "Captain", "Man the periscope. Lookout reports a freighter dead ahead."],
			["raise", "Captain", "Up periscope."],
			["range", "", ""], ["mark", "", ""],
			["lower", "Captain", "Down periscope."],
			["tdc", "Captain", "Good marks. Take the TDC."], # Arcade drops these two (see _build_steps)
			["send", "Captain", "Send the solution to the torpedo room."]]
		"torpedo": return [
			["tube", "Captain", "Torpedo room, make ready tube one."],
			["flood", "Captain", "Flood tube one and open the outer door."],
			["fire", "Captain", "Target dead ahead, gyro zero. Fire one!"],
			["reload", "Captain", "Good hit! Reload tube one."]]
		"sonar": return [
			["sonar", "Captain", "Sonar, man your station. Lookout heard screws to the north."],
			["classify", "Captain", "What is he? Warship or merchant?"],
			["plot", "Captain", "Warship. Put his bearing on the chart."]]
		"damage": return [
			["brace", "Captain", "Depth charges! Brace for it!"],
			["weld", "Control room", "Leak in the control room!"],
			["extinguish", "Control room", "Fire! Fire in the control room!"],
			["wrench", "Helmsman", "The helm's knocked out, she won't answer!"],
			["pump", "Chief of the boat", "We're taking water. Rig the portable pump!"],
			["door", "Captain", "Shut the watertight door forward."]]
		"engine": return [
			["diesel", "Captain", "Surfaced. Start a diesel and charge the battery."],
			["diesel_stop", "Bridge", "Aircraft! Clear the bridge, we're diving. Stop the diesels!"],
			["air", "Chief of the boat", "We're under. CO2's climbing back here: load a fresh canister in the scrubber.", _open_vents]]
		"attack": return [
			["scope", "Captain", "Man the periscope. Lookout reports a freighter dead ahead.", {"job": "scope"}],
			["tube", "Captain", "Torpedo room, man tube one.", {"job": "torpedo"}],
			["raise", "Captain", "Up periscope.", {"job": "scope"}],
			["range", "", "", {"job": "scope"}], ["mark", "", "", {"job": "scope"}],
			["tdc", "Captain", "Good marks. Take the TDC.", {"job": "scope"}],
			["send", "Captain", "Send the solution to the torpedo room.", {"job": "scope"}],
			["flood", "Captain", "Flood tube one and open the outer door.", {"job": "torpedo", "from": "scope"}],
			["fire", "Captain", "Target dead ahead, gyro zero. Fire one!", {"job": "torpedo", "from": "scope"}],
			["lower", "Captain", "Down periscope.", {"job": "scope"}],
			["reload", "Captain", "Good hit! Reload tube one.", {"job": "torpedo", "from": "scope"}]]
		"control": return [
			["helm", "Captain", "Helmsman, man the helm.", {"job": "helm"}],
			["dive", "Chief of the boat", "Vents open, she's flooding down. Diving officer, take the planes!", _open_vents, {"job": "dive"}],
			["sonar", "Captain", "Sonar, man your station. Lookout heard screws to the north.", {"job": "sonar"}],
			["ahead", "Captain", "All ahead two-thirds.", {"job": "helm"}],
			["depth", "Captain", "Make your depth periscope depth.", {"job": "dive"}],
			["classify", "Captain", "Sonar, what is he? Warship or merchant?", {"job": "sonar"}],
			["plot", "Captain", "Put his bearing on the chart.", {"job": "sonar"}],
			["come_090", "Captain", "Warship, closing! Right full rudder, come to zero-niner-zero.", {"job": "helm", "from": "sonar"}],
			["steady", "Captain", "Rudder amidships. Steady as she goes.", {"job": "helm"}],
			["deep_dive", "Captain", "He's still closing! Take her down to 45 metres.", {"job": "dive", "from": "sonar"}],
			["back_up", "Captain", "He's lost us. Bring her back to periscope depth.", {"job": "dive", "from": "sonar"}]]
		"party": return [
			["diesel", "Captain", "Surfaced. Start a diesel and charge the battery.", {"job": "engine"}],
			["diesel_stop", "Bridge", "Aircraft! Clear the bridge, we're diving. Stop the diesels!", {"job": "engine"}],
			["under", "Bridge", "Dive, dive!"],
			["brace", "Captain", "Depth charges! Brace for it!"],
			["weld", "Control room", "Leak in the control room!", {"job": "damage"}],
			["extinguish", "Control room", "Fire! Fire in the control room!", {"job": "damage"}],
			["air", "Chief of the boat", "That smoke's fouled the air. Load a fresh canister in the scrubber.", {"job": "engine", "from": "damage"}],
			["wrench", "Helmsman", "The helm's knocked out, she won't answer!", {"job": "engine"}],
			["pump", "Chief of the boat", "We're taking water. Rig the portable pump!", {"job": "damage", "from": "engine"}],
			["door", "Captain", "Shut the watertight door forward.", {"job": "damage"}]]
	return []


## Host: where each short course starts. Surfaced and stopped (the whole boat, helm, engine),
## or already down at periscope depth with the freighter dead ahead.
func _setup_course() -> void:
	var sub := Sim.world.sub
	match course:
		"scope", "torpedo", "sonar", "damage", "attack":
			var depth: float = 30.0 if course == "damage" else sub.data.periscope_depth
			sub.ballast = 1.0
			sub.depth = depth
			sub.ordered_depth = depth
		"engine", "party":
			sub.battery = 0.5


func _open_vents() -> void:
	Sim.world.sub.ballast_order("vent")


## Host, the damage party: under to where a pattern can hurt without being deadly.
func _dive_to_pattern() -> void:
	_open_vents()
	Sim.world.sub.ordered_depth = 30.0


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
	if _destroyer != null:
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
	if i != _called and i < steps.size() and game.crew.result == "":
		_called = i
		if steps[i].get("say", "") != "":
			game.hud.crew_call(_caller(steps[i]), steps[i].say)
	_update_marker(i)
	_update_hud(i)
	if not multiplayer.is_server() or game.crew.result != "" or i >= steps.size():
		return
	_update_jobs(i)
	if i != _entered:
		_entered = i
		var enter: Variant = steps[i].get("enter")
		if enter is Callable and (enter as Callable).is_valid():
			enter.call()
	_script_tick(i)
	if steps[i].done.call():
		_advance(i)


func _script_tick(_i: int) -> void:
	if _destroyer == null and _pattern_dropped and not _pattern_over and Sim.world.charges.is_empty():
		_pattern_over = true # the damage course's pattern, with nobody up top
		_ensure_damage()
	if _destroyer == null or _destroyer.is_sinking():
		return
	var d := _destroyer.pos.distance_to(Sim.world.sub.pos)
	if not _pattern_dropped:
		var run_in := step_number("run_in")
		var running_in := run_in >= 0 and step_index() >= run_in
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


# --- Crew courses ----------------------------------------------------------

## The player holding a job, 0 if nobody does yet.
func job_holder(job: String) -> int:
	return game.crew.tutorial.get("jobs", {}).get(job, 0)


## Host: a job goes to whoever is at one of its stations, staying with its holder while nobody
## else is. A job without stations goes, when its first step comes up, to a crewman with no job.
func _update_jobs(i: int) -> void:
	if not CREW_JOBS.has(course):
		return
	var jobs: Dictionary = game.crew.tutorial.get("jobs", {})
	var before := jobs.duplicate()
	for job: String in CREW_JOBS[course]:
		var holder: int = jobs.get(job, 0)
		if not game.crew.names.has(holder):
			holder = 0
		var stations: Array = JOBS[job].stations
		if holder == 0 or not stations.any(func(s: String) -> bool: return game.station_occupant(s) == holder):
			for s: String in stations:
				if game.station_occupant(s) > 0:
					holder = game.station_occupant(s)
					break
		if stations.is_empty() and holder == 0 and steps[i].get("job", "") == job:
			holder = _free_crewman(jobs)
		if holder != 0:
			jobs[job] = holder
		else:
			jobs.erase(job)
	if jobs != before:
		game.crew.tutorial.jobs = jobs
		game.push_crew()


func _free_crewman(jobs: Dictionary) -> int:
	var ids: Array = game.crew.names.keys()
	ids.sort()
	for id: int in ids:
		if not jobs.values().has(id):
			return id
	return ids[0] if not ids.is_empty() else 0


## Who a step's call comes from: the crewmate holding that job when there is one, and the
## scripted voice otherwise.
func _caller(step: Dictionary) -> String:
	var from: String = step.get("from", "")
	var holder := job_holder(from) if from != "" else 0
	if holder != 0 and holder != job_holder(step.get("job", "")):
		return "%s (%s)" % [game.crew_name(holder), JOBS[from].name]
	return step.who


## This step is someone else's: they hold its job, and this player doesn't.
func _waiting_on(step: Dictionary) -> int:
	var holder := job_holder(step.get("job", ""))
	return holder if holder != 0 and holder != multiplayer.get_unique_id() else 0


## What each job's holder is called, for the crew course's panel.
func _roster() -> String:
	var parts: PackedStringArray = []
	for job: String in CREW_JOBS[course]:
		var holder := job_holder(job)
		parts.append("%s: %s" % [JOBS[job].name.capitalize(), game.crew_name(holder) if holder != 0 else "open"])
	return "  ·  ".join(parts)


func _advance(i: int) -> void:
	_flags.clear() # what happens from here on counts for the next step
	game.crew.tutorial.step = i + 1
	if i + 1 >= steps.size():
		if course == "full":
			game.end_patrol("training", "Training complete. You ran the whole boat: helm, ballast, dive, scope, TDC, tubes, sonar, damage control, air and the diesels.")
		else:
			game.end_patrol("training", "Training complete: %s. Pick another job from Training patrol on the menu, or take a real patrol." % COURSES[course])
	else:
		game.announce.rpc("✓  Step %d done." % (i + 1))
	game.push_crew()


func _update_marker(i: int) -> void:
	_marker.visible = false
	if i >= steps.size() or game.crew.result != "" or _waiting_on(steps[i]) != 0:
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
	var leave := _leave_hint(steps[i])
	if leave != "":
		text = leave + "\n\n" + text
	var needs: String = steps[i].get("needs", "")
	if needs != "" and Sim.world.hull.is_broken(needs):
		var st: Station = game.interior.stations[needs]
		text += "\n\nThe %s is BROKEN. Fix it first: a WRENCH from a damage control rack, hold LMB on it." % st.display_name.to_lower()
	var hint: Variant = steps[i].get("hint")
	if hint is Callable:
		var h: String = hint.call()
		if h != "":
			text += "\n\n" + h
	if CREW_JOBS.has(course):
		text = _crew_text(steps[i], text)
	var title := "TRAINING" if course == "full" else "TRAINING: %s" % COURSES[course].to_upper()
	game.hud.set_objective("%s  %d / %d" % [title, i + 1, steps.size()], text)


## A crew course's panel: whose step this is, then who holds which job.
func _crew_text(step: Dictionary, text: String) -> String:
	var job: String = step.get("job", "")
	var waiting := _waiting_on(step)
	if waiting != 0:
		text = "Waiting on %s (%s).\n\nTheir orders: %s" % [game.crew_name(waiting), JOBS[job].name, step.text]
	elif job != "" and job_holder(job) == 0:
		text = "Nobody has the %s yet. A crewmate can take it, or do it yourself.\n\n%s" % [JOBS[job].name, text]
	return "%s\n\n%s" % [text, _roster()]


## "Press Q" when this player is at a station the step doesn't happen at. A step's station is
## its "at" (go and man it) or its "needs" (work it); "ok" lists others it's fine to stay at.
func _leave_hint(step: Dictionary) -> String:
	var me := game.local_player
	if me == null or me.station == null or _waiting_on(step) != 0:
		return ""
	var here := me.station.station_id
	var ok: Array = step.get("ok", [])
	if here == step.get("at", step.get("needs", "")) or ok.has(here) or ok.has("any"):
		return ""
	return "▶ You're at the %s. Press %s to leave it first." % [me.station.display_name.to_lower(), OS.get_keycode_string(Settings.key_for("leave_station"))]
