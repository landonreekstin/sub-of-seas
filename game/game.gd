class_name Game
extends Node3D
## Root of a patrol: builds the boat, starts the network session and the sim, spawns crew,
## and owns the crew state (doors, who mans which station, torpedo tubes). The host is
## authoritative: clients send requests (rq_*), the host validates, changes `crew` and
## broadcasts it to everyone.

const SUB_DIR := "res://data/subs/%s.tres"
const MENU_SCENE := "res://ui/main_menu.tscn"
const RELOAD_TIME := 30.0 ## seconds of hands-on work at the tube
const PING_NOTICE_GAP := 20.0 ## s between "they have us" announcements
const CLEAR_TIME := 60.0 ## s with no escort hunting nearby before the patrol counts as done
const PASS_OUT_AFTER := 6.0 ## s breathing air at its worst before a crewman passes out
const KNOCKED_OUT_TIME := 15.0

static var instance: Game

var interior: SubInterior ## built once we know the boat: at once on the host, on the first crew state on a client
var sub_class: SubClassData
var exterior: ExteriorWorld
var hud: Hud
var pause_menu: PauseMenu
var _hunted_for := 0.0 ## seconds the hunted music has left to run
var local_player: Player
var crew := {}
var _players: Node3D
var _spawner: MultiplayerSpawner
var _push_timer := 0.0
var _last_ping_notice := -INF
var _clear_timer := 0.0
var _work_clock := {} ## peer -> last time a work request was accepted (msec)
var tutorial: Tutorial
var _exposure := {} ## peer -> seconds breathing air that knocks you out
var _planes_called := {} ## plane id -> true once the lookouts have called it
var sandbox: Sandbox ## host, open patrol only
var track: Array[Vector2] = [] ## own track for the chart, sampled on every peer
var _track_timer := 0.0


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null
	Sim.stop()


func _ready() -> void:
	exterior = ExteriorWorld.create()
	add_child(exterior.viewport)
	Settings.apply_quality(exterior.viewport)
	Settings.changed.connect(func(key: String) -> void:
		if key == "quality":
			Settings.apply_quality(exterior.viewport))
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	var eye := PortholeEye.new()
	eye.game = self
	add_child(eye)
	get_viewport().size_changed.connect(_fit_exterior)
	_fit_exterior()
	hud = Hud.new()
	add_child(hud)
	move_child(pause_menu, -1)

	_players = Node3D.new()
	_players.name = "Players"
	add_child(_players)
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "PlayerSpawner"
	add_child(_spawner)
	_spawner.spawn_path = _spawner.get_path_to(_players)
	_spawner.spawn_function = _spawn_player

	Sim.event.connect(_on_sim_event)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_quit.bind("Lost connection to the host."))
	multiplayer.connection_failed.connect(_quit.bind("Could not reach a host at %s:%d." % [Net.address, Net.port]))
	multiplayer.connected_to_server.connect(func() -> void: rq_hello.rpc_id(1, Net.player_name, Net.build, Net.profile.looks()))

	var err := Net.start()
	if err != OK:
		_quit.call_deferred("Could not %s (error %d). Is the port in use?" % ["host" if Net.mode == Net.Mode.HOST else "join", err])
		return
	if multiplayer.is_server():
		_build_boat(Net.sub_key if Net.mission != "training" else "gato")
		crew = _initial_crew()
		crew.names[1] = Net.player_name
		crew.looks[1] = Net.profile.looks()
		crew.mission = Net.mission
		_setup_mission()
		if Net.debug_charges:
			_debug_pattern.call_deferred()
		if Net.debug_win:
			_debug_win.call_deferred()
		if Net.debug_torpedo:
			_debug_torpedo.call_deferred()
		if Net.debug_air:
			Sim.world.air.co2 = 4.6
			var cr := interior.comp_index("control")
			Sim.world.air.smoke[cr] = 1.0
			for d: String in crew.doors: # shut in with it: the control room stays thick
				crew.doors[d] = false
				Sim.world.hull.doors_open[d] = false
			Sim.world.hull.add_fire(cr, Sim.world.rng)
		_spawner.spawn(_spawn_data(1))
		_apply_crew()
		if crew.mission == "training":
			hud.show_message("Training patrol. Follow the checklist, top right.", 6.0)
		else:
			hud.show_message("%s\n(%s)" % [MissionData.load_key(crew.mission).briefing, Sim.world.conditions.describe()], 14.0)
	else:
		hud.show_message("Joining %s ..." % Net.address, 3.0)


## The boat: its sim, its interior and the hull model's compartments. Clients call this
## when the host's first crew state tells them which class it is.
func _build_boat(key: String) -> void:
	sub_class = load(SUB_DIR % key) if ResourceLoader.exists(SUB_DIR % key) else load(SUB_DIR % "gato")
	Sim.start(sub_class, 1234 if Net.debug_charges else -1) # fixed seed: same damage every test run
	interior = SubInterior.create(sub_class)
	add_child(interior)
	move_child(interior, 0)
	Sim.world.hull.setup(interior.compartments, interior.door_links, interior.station_compartments())
	Sim.world.air.setup(interior.compartments.size(), sub_class.co2_canisters)


func _initial_crew() -> Dictionary:
	var tubes := []
	for i in sub_class.bow_tubes + sub_class.stern_tubes:
		tubes.append({"loaded": true, "flooded": false, "door": false, "gyro": 0, "reload": 0.0, "stern": i >= sub_class.bow_tubes})
	var doors := {}
	for d: String in interior.doors:
		doors[d] = true
	return {
		"sub": sub_class.key,
		"names": {},
		"doors": doors,
		"stations": {},
		"tubes": tubes,
		"reserve": sub_class.torpedo_capacity - sub_class.bow_tubes - sub_class.stern_tubes,
		"tonnage": 0,
		"sunk": 0,
		"tools": {}, ## peer -> tool kind
		"stats": {"charges": 0, "shells": 0, "leaks": 0, "fires": 0, "repairs": 0},
		"result": "", ## set when the patrol ends: "lost" or "complete"
		"result_text": "",
		"time": 0.0,
		"mission": "convoy", ## a MissionData key, or "training"; set by the host
		"objectives": [], ## from the mission: each with "done", shown top right
		"sunk_by": {}, ## ship class key -> ships sunk
		"tutorial": {"step": 0},
		"knocked": {}, ## peer -> seconds until they come round
		"looks": {}, ## peer -> {hat, hue, rank} from their own profile
		"parts": sub_class.spare_parts, ## spare-parts boxes left in stores
		## The TDC: periscope marks on one target, the operator's nudges, and whether the
		## tubes' gyros follow its solution.
		"tdc": {"target": -1, "marks": [], "speed_adj": 0.0, "course_adj": 0.0, "follow": false},
		"plot": [], ## sonar bearings on the chart: {t, x, y (own position), b}
		"pencil": [], ## pencil marks on the chart: {x, y}
	}


func _setup_mission() -> void:
	if crew.mission == "training":
		_start_tutorial()
		tutorial.setup_world()
		_lay_seabed(true)
		return
	var m := MissionData.load_key(crew.mission)
	if m == null:
		crew.mission = MissionData.KEYS[0]
		m = MissionData.load_key(crew.mission)
	var sub := Sim.world.sub
	sub.heading = m.start_heading
	var depth: float = sub.data.periscope_depth if m.start_depth < 0.0 else m.start_depth
	if Net.debug_depth >= 0.0:
		depth = Net.debug_depth
	sub.depth = depth
	sub.ordered_depth = depth
	sub.ballast = 1.0 if depth > 0.0 else 0.0
	if depth == 0.0:
		sub.diesels.assign([1.0, 1.0]) # surfaced patrols start on the diesels
	sub.hp_air = 0.9
	sub.battery = m.battery
	sub.telegraph = m.start_speed
	sub.speed = sub.max_speed() * SubState.TELEGRAPH[m.start_speed]
	Sim.world.conditions.night = m.night
	Sim.world.conditions.sea_state = m.sea_state
	Sim.world.conditions.layer_depth = m.layer_depth
	for g: Dictionary in m.groups:
		Formations.spawn(Sim.world, g)
	if m.sandbox:
		sandbox = Sandbox.new()
	crew.objectives = m.objectives.duplicate(true)
	for o: Dictionary in crew.objectives:
		o.done = false
	_lay_seabed()
	for i in Sim.world.rng.randi_range(2, 3):
		Sim.world.add_whale(Sim.world.rng.randf_range(1500.0, 6000.0))
	if Net.debug_reef:
		_debug_reef()


## Testing aid (--reef): the boat sits stopped at 9 m just off the first island's reef, beam on
## to it, with a whale 40 m off the other side.
func _debug_reef() -> void:
	var w := Sim.world
	for f: Dictionary in w.seabed.features:
		if f.kind != "island":
			continue
		var centre := Vector2(f.x, f.y)
		var out := (w.sub.pos - centre).normalized()
		var p := centre
		while w.seabed.floor_depth(p) < 16.0:
			p += out * 5.0
		w.sub.pos = p
		w.sub.heading = fposmod(ShipState.bearing(centre, p) + 90.0, 360.0) # reef to starboard
		w.sub.depth = 9.0
		w.sub.ordered_depth = 9.0
		w.sub.telegraph = 0
		w.sub.speed = 0.0
		var wh := w.add_whale(40.0)
		wh.pos = p + out * 40.0
		wh.depth = 9.0
		return


## Islands, reefs, seamounts and shelves for this patrol, clear of the boat, of every ship's
## track (30 km on along its course) and of the run in from the boat to each ship. Training
## gets a far-off island or two to look at and nothing to hit.
func _lay_seabed(islands_only := false) -> void:
	var w := Sim.world
	var keep: Array[Vector2] = [w.sub.pos]
	var routes := []
	for s in w.ships:
		keep.append(s.pos)
		routes.append([s.pos, s.pos + s.direction() * 30000.0])
		routes.append([w.sub.pos, s.pos])
	w.seabed.generate(w.rng.randi(), w.sub.pos, keep, routes, 2500.0, islands_only)
	crew.seabed = w.seabed.to_array()


func _start_tutorial() -> void:
	if tutorial == null:
		tutorial = Tutorial.new(self)
		add_child(tutorial)


## Testing aid (--test-charges): a pattern going off around the boat a few seconds in.
func _debug_pattern() -> void:
	await get_tree().create_timer(3.0).timeout
	var sub := Sim.world.sub
	for off: Vector2 in [Vector2(4, 30), Vector2(-6, -25), Vector2(8, 5), Vector2(-30, 10), Vector2(50, -40)]:
		Sim.world.drop_charge(sub.pos + off, sub.depth - 7.0)
	await get_tree().create_timer(6.0).timeout
	Sim.world.hull.broken["helm"] = HullState.WRENCH_SECONDS # always something for the wrench
	for l in Sim.world.hull.leaks:
		print("debug leak %s at %s" % [l.id, l.p])
	for f in Sim.world.hull.fires:
		print("debug fire %s at %s" % [f.id, f.p])
	print("debug broken %s" % [Sim.world.hull.broken.keys()])


## Testing aid (--test-torpedo): a spread of three from the bow 3 s in, to see their tracks.
func _debug_torpedo() -> void:
	await get_tree().create_timer(3.0).timeout
	for gyro in [-6.0, 0.0, 6.0]:
		Sim.world.fire_torpedo(gyro)


## Testing aid (--test-win): every ship goes down 4 s in, as if torpedoed.
func _debug_win() -> void:
	await get_tree().create_timer(4.0).timeout
	for s in Sim.world.ships:
		s.hp = 0.0
		Sim.world.event.emit("sunk", {"ship": s.id, "x": s.pos.x, "y": s.pos.y, "name": s.data.display_name,
			"tons": s.data.tonnage, "class": s.data.key, "role": s.data.role})


func _fit_exterior() -> void:
	exterior.viewport.size = get_viewport().get_visible_rect().size


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("quit_to_menu"):
		_quit("")
	if interior == null or crew.is_empty():
		return # a client still waiting to hear which boat this is
	_pick_music(delta)
	if multiplayer.is_server():
		_host_tick(delta)
	_show_objectives()
	if Sim.world != null:
		_track_timer -= delta
		if _track_timer <= 0.0:
			_track_timer = 5.0
			track.append(Sim.world.sub.pos)
			if track.size() > 720:
				track.pop_front()
		var water := Sim.world.hull.water_fraction()
		hud.set_status("%s  |  crew %d  |  sunk %d (%d t)%s  |  F10 leave" % [
			sub_class.display_name, crew.names.size(), crew.sunk, crew.tonnage,
			"  |  FLOODING %d%%" % roundi(water * 100.0) if water > 0.01 else ""])


## The patrol's objectives in the top-right panel, ticked as they are done (every peer).
func _show_objectives() -> void:
	if crew.mission == "training":
		return
	if crew.result != "":
		hud.set_objective("", "")
		return
	var m := MissionData.load_key(crew.mission)
	if m == null:
		return
	var lines: Array[String] = []
	for o: Dictionary in crew.objectives:
		var progress := ""
		match o.kind:
			"tonnage":
				progress = "  (%d t)" % crew.tonnage
			"survive":
				progress = "  (%d:%02d)" % [int(Sim.world.time) / 60, int(Sim.world.time) % 60] if Sim.world != null else ""
		lines.append("%s  %s%s" % ["✓" if o.get("done", false) else "○", o.text, progress])
	hud.set_objective(m.title.to_upper(), ("\n".join(lines) + "\n\n" if not lines.is_empty() else "") + crew_roles())


## Suggested jobs for whoever is aboard, in joining order (the host first).
func crew_roles() -> String:
	var out: Array[String] = []
	var ids: Array = crew.names.keys()
	ids.sort()
	for i in ids.size():
		var role: String = sub_class.roles[i] if i < sub_class.roles.size() else "Damage control"
		out.append("%s — %s" % [crew_name(ids[i]), role])
	return "CREW\n" + "\n".join(out)


# --- Players ---------------------------------------------------------------

## Spawn data is [peer id, position]: clients may not have built the boat yet.
func _spawn_player(data: Variant) -> Node:
	return Player.create(int(data[0]), data[1])


func _spawn_data(id: int) -> Array:
	var points := interior.spawn_points
	return [id, points[absi(id) % points.size()]]


func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	print("peer %d connected" % id)
	_spawner.spawn(_spawn_data(id))
	set_crew.rpc_id(id, crew)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var p := _players.get_node_or_null(str(id))
	if p != null:
		p.queue_free()
	crew.names.erase(id)
	crew.tools.erase(id)
	_clear_stations_of(id)
	push_crew()


## The hunted track while an escort is hunting within 6 km or charges are in the water, and
## for 20 s after; the calm patrol track otherwise. Every peer decides from its own snapshot.
func _pick_music(delta: float) -> void:
	if crew.result != "" or Sim.world == null:
		return
	var w := Sim.world
	var hunted := not w.charges.is_empty() or w.ships.any(func(s: ShipState) -> bool:
		return not s.is_sinking() and s.mode >= ShipAI.Mode.HUNT and s.pos.distance_to(w.sub.pos) < 6000.0)
	_hunted_for = 20.0 if hunted else maxf(_hunted_for - delta, 0.0)
	Music.play("hunted" if _hunted_for > 0.0 else "patrol", 1.5 if hunted else 6.0)


## Back to the main menu (F10, or the pause menu).
func leave() -> void:
	_quit("")


## True while the pause menu is up: the local player's hands are off the controls.
func menu_open() -> bool:
	return pause_menu != null and pause_menu.is_open


func _quit(reason: String) -> void:
	Net.last_error = reason
	Net.stop()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU_SCENE)


# --- Crew state ------------------------------------------------------------

func station_occupant(id: String) -> int:
	return crew.stations.get(id, 0)


func crew_name(id: int) -> String:
	return crew.names.get(id, "Sailor %d" % id)


func push_crew() -> void:
	set_crew.rpc(crew)


@rpc("authority", "call_local", "reliable")
func set_crew(state: Dictionary) -> void:
	crew = state
	if interior == null:
		_build_boat(crew.sub)
	_apply_crew()


func _apply_crew() -> void:
	interior.apply_crew(crew)
	if not multiplayer.is_server() and Sim.world != null and crew.get("seabed", []) != Sim.world.seabed.features:
		Sim.world.seabed.from_array(crew.get("seabed", []))
	if crew.mission == "training":
		_start_tutorial()
	for p: Player in _players.get_children():
		var look: Dictionary = crew.get("looks", {}).get(p.peer_id, {})
		p.set_display_name("%s %s" % [Profile.RANKS[int(look.get("rank", 0))][1], crew_name(p.peer_id)])
		p.set_looks(look)
		p.set_tool(crew.tools.get(p.peer_id, ""))
	if crew.result != "" and not hud.has_debrief():
		Music.play("menu", 4.0)
		if crew.result in ["complete", "lost"]:
			Music.sting("win" if crew.result == "complete" else "lost")
		Sim.running = false
		hud.show_debrief(crew, _credit_career())
	if local_player != null:
		var held := ""
		for sid: String in crew.stations:
			if crew.stations[sid] == multiplayer.get_unique_id():
				held = sid
		local_player.sync_station(held)


## Each player's own profile takes the patrol's tonnage and ships (shared by the whole crew).
func _credit_career() -> String:
	if crew.mission == "training":
		return ""
	var p := Net.profile
	var promoted := p.credit(int(crew.tonnage), int(crew.sunk), crew.result == "complete")
	var line := "Your career: %d t in %d ships, %d patrols — %s" % [p.tons, p.ships, p.patrols, Profile.RANKS[p.rank()][0]]
	if promoted != "":
		line += "\nPROMOTED to %s!" % promoted
		for h: String in Profile.HATS:
			if int(Profile.HATS[h][1]) == p.rank():
				line += "  New hat: %s." % Profile.HATS[h][0]
	return line


func _clean_looks(l: Dictionary) -> Dictionary:
	var hat: String = l.get("hat", "dixie")
	return {"hat": hat if Profile.HATS.has(hat) else "dixie", "hue": clampf(float(l.get("hue", -1.0)), -1.0, 1.0),
		"rank": clampi(int(l.get("rank", 0)), 0, Profile.RANKS.size() - 1)}


## Host -> one client: you can't join (different build).
@rpc("authority", "call_remote", "reliable")
func turned_away(reason: String) -> void:
	_quit(reason)


@rpc("authority", "call_local", "reliable")
func announce(text: String) -> void:
	hud.show_message(text)


func _sender() -> int:
	var s := multiplayer.get_remote_sender_id()
	return s if s != 0 else multiplayer.get_unique_id()


func _clear_stations_of(peer: int) -> void:
	for sid: String in crew.stations.keys():
		if crew.stations[sid] == peer:
			crew.stations.erase(sid)


# --- Requests (run on the host) ---------------------------------------------

@rpc("any_peer", "call_local", "reliable")
func rq_hello(player_name: String, build: String, looks: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	if build != Net.build and not build.begins_with("dev") and not Net.build.begins_with("dev"):
		turned_away.rpc_id(_sender(), "The host runs build %s and you run %s. Both start the game again to update." % [Net.build, build])
		return
	crew.looks[_sender()] = _clean_looks(looks)
	crew.names[_sender()] = player_name.substr(0, 20)
	push_crew()
	announce.rpc("%s came aboard." % player_name.substr(0, 20))


@rpc("any_peer", "call_local", "reliable")
func rq_station_enter(station_id: String) -> void:
	if not multiplayer.is_server() or not interior.stations.has(station_id):
		return
	var peer := _sender()
	if station_occupant(station_id) not in [0, peer] or crew.knocked.has(peer):
		push_crew()
		return
	_clear_stations_of(peer)
	crew.stations[station_id] = peer
	push_crew()


@rpc("any_peer", "call_local", "reliable")
func rq_station_leave() -> void:
	if not multiplayer.is_server():
		return
	_clear_stations_of(_sender())
	push_crew()


@rpc("any_peer", "call_local", "reliable")
func rq_door(door_id: String) -> void:
	if not multiplayer.is_server() or not crew.doors.has(door_id):
		return
	crew.doors[door_id] = not crew.doors[door_id]
	Sim.world.hull.doors_open[door_id] = crew.doors[door_id]
	push_crew()


@rpc("any_peer", "call_local", "reliable")
func rq_order(station_id: String, key: String, value: Variant) -> void:
	if not multiplayer.is_server() or station_occupant(station_id) != _sender():
		return
	if Sim.world.hull.is_broken(station_id):
		push_crew()
		return
	var sub := Sim.world.sub
	match station_id:
		"helm":
			if key == "telegraph":
				sub.telegraph = clampi(int(value), -2, 4)
			elif key == "rudder":
				sub.rudder = clampi(int(value), -3, 3)
		"dive":
			if key == "depth":
				sub.ordered_depth = clampf(float(value), 0.0, 200.0)
		"periscope":
			if key == "raised":
				sub.periscope_raised = bool(value)
			elif key == "ranged" and tutorial != null:
				tutorial.flag("ranged")
			elif key == "mark" and value is Array and value.size() == 3:
				_tdc_mark(int(value[0]), float(value[1]), float(value[2]))
		"tdc":
			var tdc: Dictionary = crew.tdc
			match key:
				"speed":
					tdc.speed_adj = clampf(tdc.speed_adj + float(value), -30.0, 30.0)
				"course":
					tdc.course_adj = wrapf(tdc.course_adj + float(value), -180.0, 180.0)
				"clear":
					tdc.marks.clear()
					tdc.target = -1
					tdc.speed_adj = 0.0
					tdc.course_adj = 0.0
					tdc.follow = false
				"send":
					tdc.follow = not tdc.follow and not tdc.marks.is_empty()
					announce.rpc("TDC: tubes are following the solution." if tdc.follow else "TDC: tubes on manual gyro.")
					if tdc.follow and tutorial != null:
						tutorial.flag("solution")
		"engine":
			if key == "diesel" and value is Array and value.size() == 2:
				Sim.world.set_diesel(int(value[0]), bool(value[1]))
		"ballast":
			if key in ["vent", "shut", "blow", "emergency", "stop"]:
				sub.ballast_order(key)
				if key == "emergency" and sub.blowing == 2:
					announce.rpc("EMERGENCY BLOW! All main ballast tanks blowing.")
		"air":
			var air := Sim.world.air
			if key == "canister":
				if air.load_canister():
					announce.rpc("Fresh CO2 absorbent in the scrubber. %d canisters left." % air.canisters)
				else:
					announce.rpc("No CO2 absorbent left. Surface to ventilate.")
			elif key == "bleed":
				air.bleed = bool(value) and air.o2_bank > 0.0
		"sonar":
			if key == "ping":
				Sim.world.own_ping()
				announce.rpc("Sonar: PING! Every escort out there heard that.")
			elif key == "classified" and tutorial != null:
				tutorial.flag("classified")
			elif key == "plot":
				crew.plot.append({"t": Sim.world.time, "x": sub.pos.x, "y": sub.pos.y, "b": fposmod(float(value), 360.0)})
				if crew.plot.size() > 12:
					crew.plot.pop_front()
				announce.rpc("Sonar: contact bearing %03d — on the chart." % (roundi(fposmod(float(value), 360.0)) % 360))
		"nav":
			if key == "home" and sandbox != null:
				end_patrol("complete", "Home with %d tons sunk." % crew.tonnage)
			if value is Array and value.size() == 2:
				var at := Vector2(float(value[0]), float(value[1]))
				if key == "pencil" and crew.pencil.size() < 16:
					crew.pencil.append({"x": at.x, "y": at.y})
				elif key == "erase" and not crew.pencil.is_empty():
					var best := 0
					for i in crew.pencil.size():
						if Vector2(crew.pencil[i].x, crew.pencil[i].y).distance_to(at) < Vector2(crew.pencil[best].x, crew.pencil[best].y).distance_to(at):
							best = i
					crew.pencil.remove_at(best)
		_:
			if station_id.begins_with("tube_"):
				_tube_order(station_id.trim_prefix("tube_").to_int() - 1, key, value)
	push_crew()


## A periscope mark on ship `id`: true bearing and stadimeter range, as the scope saw them.
func _tdc_mark(id: int, bearing: float, range_m: float) -> void:
	var tdc: Dictionary = crew.tdc
	var ship := Sim.world.find_ship(id)
	if ship == null or range_m <= 0.0 or range_m > 12000.0:
		return
	if tdc.target != id:
		tdc.target = id
		tdc.marks.clear()
		tdc.speed_adj = 0.0
		tdc.course_adj = 0.0
	tdc.marks.append(Tdc.make_mark(Sim.world.time, Sim.world.sub.pos, fposmod(bearing, 360.0), range_m))
	# The chart keeps every target where it was last marked, after the TDC moves on.
	var at := Tdc.mark_pos(tdc.marks[-1])
	var contacts: Dictionary = crew.get_or_add("contacts", {})
	contacts[id] = {"x": at.x, "y": at.y, "t": Sim.world.time, "name": ship.data.display_name, "sunk": false}
	if tdc.marks.size() > 8:
		tdc.marks.pop_front()
	announce.rpc("MARK! Bearing %03d, range %d." % [roundi(fposmod(bearing, 360.0)) % 360, roundi(range_m / 50.0) * 50])
	if tutorial != null:
		tutorial.flag("marked")


## The live TDC solution for the bow tubes (or the stern tubes, fired astern), from crew
## state (any peer can call it).
func tdc_solution(stern := false) -> Dictionary:
	var tdc: Dictionary = crew.get("tdc", {})
	if Sim.world == null or tdc.get("marks", []).is_empty():
		return {"ok": false, "reason": "NO MARKS", "est": {"ok": false}}
	var sub := Sim.world.sub
	var est := Tdc.estimate(tdc.marks, tdc.speed_adj, tdc.course_adj)
	var launch := sub.pos + sub.direction() * sub.data.length * (-0.5 if stern else 0.5)
	var sol := Tdc.solve(est, Sim.world.time, launch, fposmod(sub.heading + (180.0 if stern else 0.0), 360.0))
	sol.est = est
	sol.quality = Tdc.quality(tdc.marks, sol.range)
	return sol


## Host: tubes whose gyros follow the TDC get the new angle as it changes.
func _tdc_follow() -> void:
	if not crew.tdc.follow:
		return
	var changed := false
	for stern in [false, true]:
		var sol := tdc_solution(stern)
		if not sol.ok:
			continue
		var g := roundi(sol.gyro)
		for t: Dictionary in crew.tubes:
			if t.get("stern", false) == stern and t.gyro != g:
				t.gyro = g
				changed = true
	if changed:
		push_crew()


func _tube_order(i: int, key: String, value: Variant) -> void:
	var t: Dictionary = crew.tubes[i]
	match key:
		"gyro":
			t.gyro = clampi(int(value), -90, 90)
			crew.tdc.follow = false # a hand on the gyro takes it off the TDC
		"flood":
			if not t.door and t.reload == 0.0:
				t.flooded = not t.flooded
		"door":
			if t.flooded:
				t.door = not t.door
		"load":
			if not t.loaded and not t.flooded and not t.door and t.reload == 0.0 and crew.reserve > 0:
				crew.reserve -= 1
				t.reload = 0.001
		"fire":
			if t.loaded and t.flooded and t.door:
				t.loaded = false
				Sim.world.fire_torpedo(float(t.gyro), t.get("stern", false))
				announce.rpc("Tube %d fired — gyro %+d°" % [i + 1, t.gyro])
				if Sim.world.rng.randf() < 0.03:
					Sim.world.hull.break_station("tube_%d" % (i + 1))
					announce.rpc("Tube %d's firing gear jammed. Wrench!" % (i + 1))


# --- Tools and damage control (run on the host) -------------------------------

func pumps_free() -> int:
	var carried: int = crew.tools.values().count("pump")
	return Tools.PUMPS_ABOARD - carried - Sim.world.hull.pumps.size() if Sim.world != null else 0


@rpc("any_peer", "call_local", "reliable")
func rq_tool(kind: String) -> void:
	if not multiplayer.is_server():
		return
	var peer := _sender()
	var had: String = crew.tools.get(peer, "")
	if kind == had:
		return
	if kind == "pump" and pumps_free() <= 0:
		return
	if kind == "parts":
		if crew.parts <= 0:
			return
		crew.parts -= 1
	if had == "parts":
		crew.parts += 1 # put back in stores
	if kind == "":
		crew.tools.erase(peer)
	elif Tools.KINDS.has(kind):
		crew.tools[peer] = kind
	push_crew()


@rpc("any_peer", "call_local", "reliable")
func rq_work(tool: String, target: String, seconds: float) -> void:
	if not multiplayer.is_server() or Sim.world == null:
		return
	var peer := _sender()
	if crew.tools.get(peer, "") != tool:
		return
	# Never credit more work than real time has passed since this peer's last request.
	var now := Time.get_ticks_msec()
	var since: float = (now - int(_work_clock.get(peer, now - 250))) / 1000.0
	_work_clock[peer] = now
	var hull := Sim.world.hull
	if not hull.work(tool, target, minf(seconds, since)):
		return
	var who := crew_name(peer)
	match tool:
		"torch":
			crew.stats.leaks += 1
			announce.rpc("%s welded a leak shut." % who)
		"extinguisher":
			crew.stats.fires += 1
			announce.rpc("%s put out a fire." % who)
		"wrench":
			crew.stats.repairs += 1
			var st: Station = interior.stations.get(target)
			announce.rpc("%s repaired the %s." % [who, st.display_name.to_lower() if st != null else target])
		"parts":
			crew.tools.erase(peer) # used up
			var st: Station = interior.stations.get(target)
			announce.rpc("%s fitted spare parts to the %s. Now a wrench." % [who, st.display_name.to_lower() if st != null else target])
	push_crew()


@rpc("any_peer", "call_local", "reliable")
func rq_place_pump(pos: Vector3) -> void:
	if not multiplayer.is_server() or crew.tools.get(_sender(), "") != "pump":
		return
	var hull := Sim.world.hull
	hull.pumps.append({"c": hull.comp_at(pos.z), "p": Vector3(pos.x, maxf(pos.y, 0.0), pos.z)})
	crew.tools.erase(_sender())
	push_crew()


@rpc("any_peer", "call_local", "reliable")
func rq_take_pump(index: int) -> void:
	var hull := Sim.world.hull
	if not multiplayer.is_server() or index < 0 or index >= hull.pumps.size() or crew.tools.has(_sender()):
		return
	hull.pumps.remove_at(index)
	crew.tools[_sender()] = "pump"
	push_crew()


func end_patrol(result: String, text: String) -> void:
	if crew.result != "":
		return
	crew.result = result
	crew.result_text = text
	crew.time = Sim.world.time
	push_crew()


func _host_tick(delta: float) -> void:
	if Sim.world == null or crew.result != "":
		return
	var sub := Sim.world.sub
	if sub.periscope_raised and Sim.world.hull.is_broken("periscope"):
		sub.periscope_raised = false
	Sim.world.crew_count = crew.names.size()
	_breathe(delta)
	_tdc_follow()
	_lookouts()
	if sandbox != null:
		sandbox.tick(Sim.world, delta)
	_check_patrol_complete(delta)
	var reloading := false
	for i in crew.tubes.size():
		var t: Dictionary = crew.tubes[i]
		if t.reload > 0.0 and station_occupant("tube_%d" % (i + 1)) != 0:
			reloading = true
			# A small crew has its hands full: reloads go a little quicker with fewer aboard.
			t.reload += delta / (RELOAD_TIME * clampf(0.6 + 0.1 * crew.names.size(), 0.8, 1.2))
			if t.reload >= 1.0:
				t.reload = 0.0
				t.loaded = true
				announce.rpc("Tube %d loaded." % (i + 1))
				push_crew()
	if reloading:
		_push_timer += delta
		if _push_timer > 0.25:
			_push_timer = 0.0
			push_crew()


## Surfaced, the lookouts call any plane within 7 km (by day; 2 km at night).
func _lookouts() -> void:
	var w := Sim.world
	if not w.sub.is_surfaced():
		return
	var r := 7000.0 * (0.3 if w.conditions.night else 1.0)
	for p in w.planes:
		if not _planes_called.has(p.id) and p.pos.distance_to(w.sub.pos) < r:
			_planes_called[p.id] = true
			announce.rpc("AIRCRAFT, bearing %03d! Clear the bridge — DIVE, DIVE!" % (roundi(ShipState.bearing(w.sub.pos, p.pos)) % 360))
			alarm.rpc()


@rpc("authority", "call_local", "reliable")
func alarm() -> void:
	Sfx.play("klaxon")


## Bad air or thick smoke where a crewman stands knocks him out for a while; he comes round
## in the compartment with the best air.
func _breathe(delta: float) -> void:
	var w := Sim.world
	var changed := false
	for p: Player in _players.get_children():
		var peer := p.peer_id
		if crew.knocked.has(peer):
			crew.knocked[peer] -= delta
			if crew.knocked[peer] <= 0.0:
				crew.knocked.erase(peer)
				_exposure.erase(peer)
				wake_at.rpc_id(peer, _best_air_spot())
				changed = true
			continue
		var bad := w.air.badness_in(w.hull.comp_at(p.global_position.z))
		_exposure[peer] = _exposure.get(peer, 0.0) + delta if bad >= 1.0 else 0.0
		if _exposure[peer] >= PASS_OUT_AFTER:
			crew.knocked[peer] = KNOCKED_OUT_TIME
			crew.tools.erase(peer)
			_clear_stations_of(peer)
			announce.rpc("%s passed out!" % crew_name(peer))
			changed = true
	if changed:
		push_crew()


func _best_air_spot() -> Vector3:
	var w := Sim.world
	var best := 0
	var best_score := INF
	for i in w.hull.comps.size():
		var score: float = w.air.badness_in(i) + w.hull.comps[i].water * 2.0
		if score < best_score:
			best_score = score
			best = i
	var c: Dictionary = w.hull.comps[best]
	return Vector3(randf_range(-0.5, 0.5), 0.1, (c.z0 + c.z1) * 0.5 + randf_range(-1.0, 1.0))


## Host -> one crewman: you come round here.
@rpc("authority", "call_local", "reliable")
func wake_at(pos: Vector3) -> void:
	if local_player != null:
		local_player.global_position = pos
		local_player.velocity = Vector3.ZERO
	hud.show_message("You come round, coughing.", 3.0)


## Ticks objectives off. The patrol is complete when the main ones are done and no escort has
## been hunting nearby for a minute (a "survive" patrol ends as soon as time is up); it ends
## early if the targets can no longer be sunk (all gone, or out of reach).
func _check_patrol_complete(delta: float) -> void:
	if crew.mission == "training" or crew.objectives.is_empty():
		return # the open patrol ends when the crew heads home
	var w := Sim.world
	var changed := false
	var all_done := true
	var hopeless := false
	var survive := false
	for o: Dictionary in crew.objectives:
		var was: bool = o.done
		match o.kind:
			"tonnage":
				o.done = crew.tonnage >= int(o.value)
				if not o.done:
					var afloat := 0
					for s in _targets(o):
						afloat += s.data.tonnage
					hopeless = hopeless or crew.tonnage + afloat < int(o.value)
			"sink_class", "sink_role":
				var n := _sunk_count(o)
				o.done = n >= int(o.count)
				if not o.done and not o.get("bonus", false):
					hopeless = hopeless or n + _targets(o).size() < int(o.count)
			"survive":
				survive = true
				o.done = w.time >= float(o.value)
		changed = changed or was != o.done
		if not o.done and not o.get("bonus", false):
			all_done = false
	if changed:
		push_crew()
	if all_done and survive:
		end_patrol("complete", "They gave up the hunt. We made it.")
		return
	if hopeless:
		end_patrol("escaped", "The targets got away.")
		return
	var hunted := w.ships.any(func(s: ShipState) -> bool:
		return s.ai != null and not s.is_sinking() and s.ai.mode >= ShipAI.Mode.HUNT and s.pos.distance_to(w.sub.pos) < 5000.0)
	_clear_timer = 0.0 if hunted or not all_done else _clear_timer + delta
	if _clear_timer >= CLEAR_TIME:
		end_patrol("complete", "Objectives done and the escorts shaken off.")


func _sunk_count(o: Dictionary) -> int:
	var n := 0
	for k: String in crew.sunk_by:
		var data := Formations.ship_class(k)
		if (o.kind == "sink_class" and k == o.get("class", "")) or (o.kind == "sink_role" and data.role == o.get("role", "")) or o.kind == "tonnage":
			n += int(crew.sunk_by[k])
	return n


## Ships still afloat and within 25 km that would count towards objective `o`.
func _targets(o: Dictionary) -> Array[ShipState]:
	var out: Array[ShipState] = []
	for s in Sim.world.ships:
		if s.is_sinking() or s.pos.distance_to(Sim.world.sub.pos) > 25000.0:
			continue
		var fits: bool = (o.kind == "tonnage" and s.data.role == "merchant") or (o.kind == "sink_class" and s.data.key == o.get("class", "")) \
			or (o.kind == "sink_role" and s.data.role == o.get("role", ""))
		if fits or (o.kind == "tonnage" and s.data.role != "merchant"):
			out.append(s)
	return out


## What the crew hears of a sim event. Sonar-only sounds need the local player on the sonar.
func _event_sound(kind: String, data: Dictionary) -> void:
	var on_sonar := local_player != null and local_player.station != null and local_player.station.station_id == "sonar"
	match kind:
		"blast":
			if data.get("shell", false):
				Sfx.play("shell_hit")
				return
			var d: float = data.dist
			if d < DepthCharge.SHAKE * 3.0:
				Sfx.play("depth_charge", lerpf(-4.0, -20.0, clampf(d / (DepthCharge.SHAKE * 3.0), 0.0, 1.0)), lerpf(0.9, 1.1, randf()))
			if d < DepthCharge.HEAVY:
				Sfx.play("alarm", -6.0)
		"ping":
			if data.echo:
				Sfx.play("echo_ranging")
			elif on_sonar:
				Sfx.play("echo_ranging", -14.0, 0.95)
		"splash":
			if on_sonar:
				Sfx.play("splash")
		"own_ping":
			Sfx.play("sonar_ping")
		"fired":
			Sfx.play("torpedo_launch")
		"hit", "beached":
			Sfx.play("torpedo_hit")
		"grounded":
			Sfx.play("clang", 4.0 if data.hard else -2.0, 0.6)
			Sfx.play("creak_%d" % randi_range(1, 3), 0.0, 0.7)
		"sunk":
			Sfx.play("creak_%d" % randi_range(1, 3), -4.0, 0.5) # breaking up


func _on_sim_event(kind: String, data: Dictionary) -> void:
	_event_sound(kind, data)
	if kind == "hit" or kind == "beached":
		exterior.explosion(Vector2(data.x, data.y))
	elif kind == "grounded" and local_player != null:
		local_player.add_trauma(0.8 if data.hard else 0.3)
	elif kind == "shell":
		exterior.water_column(Vector2(data.x, data.y), 4.0)
	elif kind == "blast":
		exterior.water_column(Vector2(data.x, data.y), data.d)
		var dist: float = data.dist
		if local_player != null and dist < DepthCharge.SHAKE:
			local_player.add_trauma(clampf((DepthCharge.SHAKE - dist) / 70.0, 0.15, 1.0))
		if dist < DepthCharge.LIGHT + 15.0:
			var strength := clampf((DepthCharge.LIGHT + 15.0 - dist) / 40.0, 0.3, 1.0)
			interior.flicker(strength)
			interior.shake_loose(strength)
	if not multiplayer.is_server():
		return
	match kind:
		"ping":
			var now := Sim.world.time
			if data.echo and now - _last_ping_notice > PING_NOTICE_GAP:
				_last_ping_notice = now
				announce.rpc("PING ... PING ... sonar's got us on the hull.")
		"blast":
			if data.get("shell", false):
				crew.stats.shells += 1
				data.dmg.push_front("SHELL HIT!")
			elif data.dist < DepthCharge.SHAKE:
				crew.stats.charges += 1
			var lines: Array[String] = []
			for m: String in data.dmg:
				if m.begins_with("BROKEN:"):
					var st: Station = interior.stations.get(m.trim_prefix("BROKEN:"))
					lines.append("%s knocked out!" % (st.display_name if st != null else "Equipment"))
				else:
					lines.append(m)
			if not lines.is_empty():
				announce.rpc("  ".join(lines))
			push_crew()
		"spotted":
			announce.rpc("The convoy is zig-zagging. They've spotted us!")
		"aircraft":
			announce.rpc("The plane has seen us! Escorts will be coming.")
		"leak", "power", "breakdown", "grounded":
			announce.rpc(data.text)
			push_crew()
		"beached":
			announce.rpc("A torpedo ran into the shallows and went off.")
		"lost":
			end_patrol("lost", data.reason)
		"hit":
			announce.rpc("HIT! %s" % data.name)
		"dud":
			announce.rpc("Dud... clang on the %s's hull. They know we're here." % data.name)
		"sunk":
			crew.sunk += 1
			crew.tonnage += int(data.tons)
			if crew.get("contacts", {}).has(int(data.ship)):
				crew.contacts[int(data.ship)].sunk = true
			crew.sunk_by[data["class"]] = int(crew.sunk_by.get(data["class"], 0)) + 1
			push_crew()
			var left := Sim.world.ships.filter(func(s: ShipState) -> bool: return not s.is_sinking()).size()
			announce.rpc("%s SUNK — %d tons.%s" % [data.name, data.tons, " Nothing left afloat!" if left == 0 else ""])
