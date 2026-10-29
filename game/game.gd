class_name Game
extends Node3D
## Root of a patrol: builds the boat, starts the network session and the sim, spawns crew,
## and owns the crew state (doors, who mans which station, torpedo tubes). The host is
## authoritative: clients send requests (rq_*), the host validates, changes `crew` and
## broadcasts it to everyone.

const GATO := preload("res://data/subs/gato.tres")
const FREIGHTER := preload("res://data/ships/freighter.tres")
const DESTROYER := preload("res://data/ships/destroyer.tres")
const MENU_SCENE := "res://ui/main_menu.tscn"
const RELOAD_TIME := 30.0 ## seconds of hands-on work at the tube
const PING_NOTICE_GAP := 20.0 ## s between "they have us" announcements
const CLEAR_TIME := 60.0 ## s with no escort hunting nearby before the patrol counts as done

static var instance: Game

var interior: GatoInterior
var exterior: ExteriorWorld
var hud: Hud
var local_player: Player
var crew := {}
var _players: Node3D
var _spawner: MultiplayerSpawner
var _push_timer := 0.0
var _last_ping_notice := -INF
var _clear_timer := 0.0
var _work_clock := {} ## peer -> last time a work request was accepted (msec)
var tutorial: Tutorial


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null
	Sim.stop()


func _ready() -> void:
	crew = _initial_crew()
	Sim.start(GATO, 1234 if Net.debug_charges else -1) # fixed seed: same damage every test run
	interior = GatoInterior.new()
	interior.name = "Interior"
	add_child(interior)
	Sim.world.hull.setup(GatoInterior.COMPARTMENTS, GatoInterior.DOOR_LINKS, interior.station_compartments())
	exterior = ExteriorWorld.create()
	add_child(exterior.viewport)
	get_viewport().size_changed.connect(_fit_exterior)
	_fit_exterior()
	hud = Hud.new()
	add_child(hud)

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
	multiplayer.connected_to_server.connect(func() -> void: rq_hello.rpc_id(1, Net.player_name, Net.build))

	var err := Net.start()
	if err != OK:
		_quit.call_deferred("Could not %s (error %d). Is the port in use?" % ["host" if Net.mode == Net.Mode.HOST else "join", err])
		return
	if multiplayer.is_server():
		crew.names[1] = Net.player_name
		crew.mission = Net.mission
		_setup_mission()
		if Net.debug_charges:
			_debug_pattern.call_deferred()
		_spawner.spawn(1)
		_apply_crew()
		if crew.mission == "training":
			hud.show_message("Training patrol. Follow the checklist, top right.", 6.0)
		else:
			hud.show_message("Patrol started. Two freighters and a destroyer escort reported to the north.", 6.0)
	else:
		hud.show_message("Joining %s ..." % Net.address, 3.0)


func _initial_crew() -> Dictionary:
	var tubes := []
	for i in GATO.bow_tubes:
		tubes.append({"loaded": true, "flooded": false, "door": false, "gyro": 0, "reload": 0.0})
	return {
		"names": {},
		"doors": {"fwd": true, "aft": true},
		"stations": {},
		"tubes": tubes,
		"reserve": GATO.torpedo_capacity - GATO.bow_tubes - GATO.stern_tubes,
		"tonnage": 0,
		"sunk": 0,
		"tools": {}, ## peer -> tool kind
		"stats": {"charges": 0, "leaks": 0, "fires": 0, "repairs": 0},
		"result": "", ## set when the patrol ends: "lost" or "complete"
		"result_text": "",
		"time": 0.0,
		"mission": "patrol", ## "patrol" | "training", set by the host
		"tutorial": {"step": 0},
	}


func _setup_mission() -> void:
	if crew.mission == "training":
		_start_tutorial()
		tutorial.setup_world()
		return
	var sub := Sim.world.sub
	sub.depth = sub.data.periscope_depth
	sub.battery = 0.8
	sub.ordered_depth = sub.data.periscope_depth
	sub.telegraph = 1
	sub.speed = sub.max_speed() * 0.25
	var lead := Sim.world.add_ship(FREIGHTER, Vector2(1800, 3200), 270.0, 8.0)
	Sim.world.add_ship(FREIGHTER, Vector2(2400, 3550), 270.0, 8.0)
	# The escort screens ahead of the convoy, a little to the side nearer the sub.
	var dd := Sim.world.add_ship(DESTROYER, Vector2(700, 3000), 270.0, 8.0)
	Sim.world.set_escort(dd, lead, Vector2(-500, 1100))


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


func _fit_exterior() -> void:
	exterior.viewport.size = get_viewport().get_visible_rect().size


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("quit_to_menu"):
		_quit("")
	if multiplayer.is_server():
		_host_tick(delta)
	if Sim.world != null:
		var water := Sim.world.hull.water_fraction()
		hud.set_status("%s  |  crew %d  |  sunk %d (%d t)%s  |  F10 leave" % [
			GATO.display_name, crew.names.size(), crew.sunk, crew.tonnage,
			"  |  FLOODING %d%%" % roundi(water * 100.0) if water > 0.01 else ""])


# --- Players ---------------------------------------------------------------

func _spawn_player(id: int) -> Node:
	var points := interior.spawn_points
	return Player.create(id, points[absi(id) % points.size()])


func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	print("peer %d connected" % id)
	_spawner.spawn(id)
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


func _quit(reason: String) -> void:
	Net.last_error = reason
	Net.stop()
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
	_apply_crew()


func _apply_crew() -> void:
	interior.apply_crew(crew)
	if crew.mission == "training":
		_start_tutorial()
	for p: Player in _players.get_children():
		p.set_display_name(crew_name(p.peer_id))
		p.set_tool(crew.tools.get(p.peer_id, ""))
	if crew.result != "" and not hud.has_debrief():
		Sim.running = false
		hud.show_debrief(crew)
	if local_player != null:
		var held := ""
		for sid: String in crew.stations:
			if crew.stations[sid] == multiplayer.get_unique_id():
				held = sid
		local_player.sync_station(held)


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
func rq_hello(player_name: String, build: String) -> void:
	if not multiplayer.is_server():
		return
	if build != Net.build and "dev" not in [build, Net.build]:
		turned_away.rpc_id(_sender(), "The host runs build %s and you run %s. Both start the game again to update." % [Net.build, build])
		return
	crew.names[_sender()] = player_name.substr(0, 20)
	push_crew()
	announce.rpc("%s came aboard." % player_name.substr(0, 20))


@rpc("any_peer", "call_local", "reliable")
func rq_station_enter(station_id: String) -> void:
	if not multiplayer.is_server() or not interior.stations.has(station_id):
		return
	var peer := _sender()
	if station_occupant(station_id) not in [0, peer]:
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
		"engine":
			if key == "diesel" and value is Array and value.size() == 2:
				Sim.world.set_diesel(int(value[0]), bool(value[1]))
		"sonar":
			if key == "ping":
				Sim.world.own_ping()
				announce.rpc("Sonar: PING! Every escort out there heard that.")
			elif key == "classified" and tutorial != null:
				tutorial.flag("classified")
		_:
			if station_id.begins_with("tube_"):
				_tube_order(station_id.trim_prefix("tube_").to_int() - 1, key, value)
	push_crew()


func _tube_order(i: int, key: String, value: Variant) -> void:
	var t: Dictionary = crew.tubes[i]
	match key:
		"gyro":
			t.gyro = clampi(int(value), -90, 90)
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
				Sim.world.fire_torpedo(float(t.gyro))
				announce.rpc("Tube %d fired — gyro %+d°" % [i + 1, t.gyro])


# --- Tools and damage control (run on the host) -------------------------------

func pumps_free() -> int:
	var carried: int = crew.tools.values().count("pump")
	return Tools.PUMPS_ABOARD - carried - Sim.world.hull.pumps.size() if Sim.world != null else 0


@rpc("any_peer", "call_local", "reliable")
func rq_tool(kind: String) -> void:
	if not multiplayer.is_server():
		return
	var peer := _sender()
	if kind == "":
		crew.tools.erase(peer)
	elif Tools.KINDS.has(kind):
		if kind == "pump" and crew.tools.get(peer, "") != "pump" and pumps_free() <= 0:
			return
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
	_check_patrol_complete(delta)
	var reloading := false
	for i in crew.tubes.size():
		var t: Dictionary = crew.tubes[i]
		if t.reload > 0.0 and station_occupant("tube_%d" % (i + 1)) != 0:
			reloading = true
			t.reload += delta / RELOAD_TIME
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


## Done when every merchant is sunk and no escort has been hunting nearby for a minute.
func _check_patrol_complete(delta: float) -> void:
	if crew.mission == "training":
		return
	var w := Sim.world
	var merchants := w.ships.filter(func(s: ShipState) -> bool: return s.ai == null and not s.is_sinking())
	if not merchants.is_empty() or crew.sunk == 0:
		_clear_timer = 0.0
		return
	var hunted := w.ships.any(func(s: ShipState) -> bool:
		return s.ai != null and not s.is_sinking() and s.ai.mode >= ShipAI.Mode.HUNT and s.pos.distance_to(w.sub.pos) < 5000.0)
	_clear_timer = 0.0 if hunted else _clear_timer + delta
	if _clear_timer >= CLEAR_TIME:
		end_patrol("complete", "Convoy destroyed and the escort shaken off.")


func _on_sim_event(kind: String, data: Dictionary) -> void:
	if kind == "hit":
		exterior.explosion(Vector2(data.x, data.y))
	elif kind == "blast":
		exterior.water_column(Vector2(data.x, data.y), data.d)
		var dist: float = data.dist
		if local_player != null and dist < DepthCharge.SHAKE:
			local_player.add_trauma(clampf((DepthCharge.SHAKE - dist) / 70.0, 0.15, 1.0))
		if dist < DepthCharge.LIGHT + 15.0:
			interior.flicker(clampf((DepthCharge.LIGHT + 15.0 - dist) / 40.0, 0.3, 1.0))
	if not multiplayer.is_server():
		return
	match kind:
		"ping":
			var now := Sim.world.time
			if data.echo and now - _last_ping_notice > PING_NOTICE_GAP:
				_last_ping_notice = now
				announce.rpc("PING ... PING ... sonar's got us on the hull.")
		"blast":
			if data.dist < DepthCharge.SHAKE:
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
		"leak", "power":
			announce.rpc(data.text)
		"lost":
			end_patrol("lost", data.reason)
		"hit":
			announce.rpc("HIT! %s" % data.name)
		"dud":
			announce.rpc("Dud... clang on the %s's hull. They know we're here." % data.name)
		"sunk":
			crew.sunk += 1
			crew.tonnage += int(data.tons)
			push_crew()
			var left := Sim.world.ships.filter(func(s: ShipState) -> bool: return not s.is_sinking()).size()
			announce.rpc("%s SUNK — %d tons.%s" % [data.name, data.tons, " Convoy destroyed!" if left == 0 else ""])
