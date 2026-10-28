class_name Game
extends Node3D
## Root of a patrol: builds the boat, starts the network session and the sim, spawns crew,
## and owns the crew state (doors, who mans which station, torpedo tubes). The host is
## authoritative: clients send requests (rq_*), the host validates, changes `crew` and
## broadcasts it to everyone.

const GATO := preload("res://data/subs/gato.tres")
const FREIGHTER := preload("res://data/ships/freighter.tres")
const MENU_SCENE := "res://ui/main_menu.tscn"
const RELOAD_TIME := 30.0 ## seconds of hands-on work at the tube

static var instance: Game

var interior: GatoInterior
var exterior: ExteriorWorld
var hud: Hud
var local_player: Player
var crew := {}
var _players: Node3D
var _spawner: MultiplayerSpawner
var _push_timer := 0.0


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null
	Sim.stop()


func _ready() -> void:
	crew = _initial_crew()
	Sim.start(GATO)
	interior = GatoInterior.new()
	interior.name = "Interior"
	add_child(interior)
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
	multiplayer.connection_failed.connect(_quit.bind("Could not reach a host at %s:%d." % [Net.address, Net.PORT]))
	multiplayer.connected_to_server.connect(func() -> void: rq_hello.rpc_id(1, Net.player_name))

	var err := Net.start()
	if err != OK:
		_quit.call_deferred("Could not %s (error %d). Is the port in use?" % ["host" if Net.mode == Net.Mode.HOST else "join", err])
		return
	if multiplayer.is_server():
		crew.names[1] = Net.player_name
		_setup_mission()
		_spawner.spawn(1)
		_apply_crew()
		hud.show_message("Patrol started. Two freighters reported to the north.", 6.0)
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
	}


func _setup_mission() -> void:
	var sub := Sim.world.sub
	sub.depth = sub.data.periscope_depth
	sub.ordered_depth = sub.data.periscope_depth
	sub.telegraph = 1
	sub.speed = sub.max_speed() * 0.25
	Sim.world.add_ship(FREIGHTER, Vector2(1800, 3200), 270.0, 8.0)
	Sim.world.add_ship(FREIGHTER, Vector2(2400, 3550), 270.0, 8.0)


func _fit_exterior() -> void:
	exterior.viewport.size = get_viewport().get_visible_rect().size


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("quit_to_menu"):
		_quit("")
	if multiplayer.is_server():
		_host_tick(delta)
	if Sim.world != null:
		hud.set_status("%s  |  crew %d  |  sunk %d (%d t)  |  F10 leave" % [
			GATO.display_name, crew.names.size(), crew.sunk, crew.tonnage])


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
	_clear_stations_of(id)
	_push_crew()


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


func _push_crew() -> void:
	set_crew.rpc(crew)


@rpc("authority", "call_local", "reliable")
func set_crew(state: Dictionary) -> void:
	crew = state
	_apply_crew()


func _apply_crew() -> void:
	interior.apply_crew(crew)
	for p: Player in _players.get_children():
		p.set_display_name(crew_name(p.peer_id))
	if local_player != null:
		var held := ""
		for sid: String in crew.stations:
			if crew.stations[sid] == multiplayer.get_unique_id():
				held = sid
		local_player.sync_station(held)


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
func rq_hello(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	crew.names[_sender()] = player_name.substr(0, 20)
	_push_crew()
	announce.rpc("%s came aboard." % player_name.substr(0, 20))


@rpc("any_peer", "call_local", "reliable")
func rq_station_enter(station_id: String) -> void:
	if not multiplayer.is_server() or not interior.stations.has(station_id):
		return
	var peer := _sender()
	if station_occupant(station_id) not in [0, peer]:
		_push_crew()
		return
	_clear_stations_of(peer)
	crew.stations[station_id] = peer
	_push_crew()


@rpc("any_peer", "call_local", "reliable")
func rq_station_leave() -> void:
	if not multiplayer.is_server():
		return
	_clear_stations_of(_sender())
	_push_crew()


@rpc("any_peer", "call_local", "reliable")
func rq_door(door_id: String) -> void:
	if not multiplayer.is_server() or not crew.doors.has(door_id):
		return
	crew.doors[door_id] = not crew.doors[door_id]
	_push_crew()


@rpc("any_peer", "call_local", "reliable")
func rq_order(station_id: String, key: String, value: Variant) -> void:
	if not multiplayer.is_server() or station_occupant(station_id) != _sender():
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
		_:
			if station_id.begins_with("tube_"):
				_tube_order(station_id.trim_prefix("tube_").to_int() - 1, key, value)
	_push_crew()


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


func _host_tick(delta: float) -> void:
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
				_push_crew()
	if reloading:
		_push_timer += delta
		if _push_timer > 0.25:
			_push_timer = 0.0
			_push_crew()


func _on_sim_event(kind: String, data: Dictionary) -> void:
	if kind == "hit":
		exterior.explosion(Vector2(data.x, data.y))
	if not multiplayer.is_server():
		return
	match kind:
		"hit":
			announce.rpc("HIT! %s" % data.name)
		"dud":
			announce.rpc("Dud... clang on the %s's hull. They know we're here." % data.name)
		"sunk":
			crew.sunk += 1
			crew.tonnage += int(data.tons)
			_push_crew()
			var left := Sim.world.ships.filter(func(s: ShipState) -> bool: return not s.is_sinking()).size()
			announce.rpc("%s SUNK — %d tons.%s" % [data.name, data.tons, " Convoy destroyed!" if left == 0 else ""])
