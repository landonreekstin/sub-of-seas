class_name Game
extends Node3D
## Root of a patrol: builds the boat, starts the network session and the sim, spawns crew,
## and owns the crew state (doors, who mans which station, torpedo tubes). The host is
## authoritative: clients send requests (rq_*), the host validates, changes `crew` and
## broadcasts it to everyone.

const SUB_DIR := "res://data/subs/%s.tres"
const MENU_SCENE := "res://ui/main_menu.tscn"
const RELOAD_TIME := 30.0 ## seconds of hands-on work at the tube
const HELP_RELOAD := 1.7 ## a second crewmate on the hoist speeds a reload this much
const HELP_REACH := 2.2 ## metres from the tube (along the deck) a helper stands
const PING_NOTICE_GAP := 20.0 ## s between "they have us" announcements
const CAVE_RUN_IN := 500.0 ## m from the start to the cave's mouth, on a cave challenge
const CLEAR_TIME := 60.0 ## s with no escort hunting nearby before the patrol counts as done
const PASS_OUT_AFTER := 6.0 ## s breathing air at its worst before a crewman passes out
const KNOCKED_OUT_TIME := 15.0
const PASS_TIME := 1.5 ## s for the ammunition party to pass one round up to the gun
const JOIN_TIMEOUT := 20.0 ## s a joining client waits for the boat before giving up

static var instance: Game

var _fun_rng := RandomNumberGenerator.new() ## the pastimes' cards
var _arm_push_timer := 0.0
var deck: Deck ## the casing out on deck (built with the boat)
var _deck_notice := -INF ## when "crew on deck" was last announced
var _ring_free_at := 0.0 ## sim time the wrestling ring takes a new bout
var interior: SubInterior ## built once we know the boat: at once on the host, on the first crew state on a client
var sub_class: SubClassData
var exterior: ExteriorWorld
var hud: Hud
var pause_menu: PauseMenu
var bot_crew: BotCrew
var bot_orders: BotOrders ## open while the local player gives a bot orders
var things_to_do: ThingsToDo ## the T card: every pastime aboard
var known := ChartKnown.new() ## what we've seen of the map, while crew.limited_map (an enemy-sub fight)
var _known_timer := 0.0
var pa_panel: PaPanel ## open while the local player has the PA microphone
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
var _in_rain := false ## host: the lookouts have called a squall over us


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
	bot_crew = BotCrew.new()
	bot_crew.game = self
	add_child(bot_crew)
	get_viewport().size_changed.connect(_fit_exterior)
	_fit_exterior()
	hud = Hud.new()
	add_child(hud)
	things_to_do = ThingsToDo.new()
	things_to_do.theme = UiKit.theme()
	hud.add_child(things_to_do)
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
		if not Net.dedicated:
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
		if Net.debug_breach:
			_debug_breach.call_deferred()
		for sid in Net.start_bots:
			bot_crew.request.call_deferred(sid, "post", null)
		if Net.debug_air:
			Sim.world.air.co2 = 4.6
			var cr := interior.comp_index("control")
			Sim.world.air.smoke[cr] = 1.0
			for d: String in crew.doors: # shut in with it: the control room stays thick
				crew.doors[d] = false
				Sim.world.hull.doors_open[d] = false
			Sim.world.hull.add_fire(cr, Sim.world.rng)
		if Net.dedicated:
			print("server: hosting %s in a %s on port %d, build %s. Waiting for a crew." % [crew.mission, sub_class.display_name, Net.port, Net.build])
		else:
			_spawner.spawn(_spawn_data(1))
		_apply_crew()
		if crew.mission == "training":
			hud.show_message("Training patrol. Follow the checklist, top right.", 6.0)
		else:
			hud.show_message("%s\n(%s)" % [MissionData.load_key(crew.mission).briefing, Sim.world.conditions.describe()], 14.0)
	else:
		hud.show_message("Joining %s ..." % Net.address, 3.0)
		get_tree().create_timer(JOIN_TIMEOUT).timeout.connect(_check_joined)


## A client still without a boat this long after joining gives up and says why, instead of
## a grey screen. Different builds (one from before the ZSTD change) never finish connecting.
func _check_joined() -> void:
	if interior == null:
		_quit("No answer from the host at %s:%d after %d seconds.\nIf the host is up, you are probably on different versions of the game:\ncompare the version on both main menus." % [Net.address, Net.port, int(JOIN_TIMEOUT)])


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
	deck = Deck.create(sub_class)
	add_child(deck)


func players() -> Array[Node]:
	return _players.get_children()


## Is this instrument on its rack (nobody holding it)?
func instrument_free(kind: String) -> bool:
	return not crew.get("tools", {}).values().has(kind)


## Host: is anyone out on deck or in the sea round her without a dive suit? (Divers in suits
## stay out while she dives: Diving.)
func crew_on_deck() -> bool:
	for p: Player in _players.get_children():
		if Deck.is_out(p.global_position) and not Diving.suited(p.peer_id) and not p.godly():
			return true
	return false


## Host: the boat can't dive with anyone out on deck (Blaney). Says so, now and then.
func _deck_blocks_dive() -> bool:
	if not crew_on_deck():
		return false
	if Sim.world.time - _deck_notice > 6.0:
		_deck_notice = Sim.world.time
		announce.rpc("Can't dive: there's crew out on deck without a dive suit! Get them below or suited up first.")
	return true


## Host: the wrestling ring on the aft casing (Wrestling). Two crewmen standing in it start a
## bout; each turn waits for both moves (or the clock), plays out, and ends when one goes in.
func _wrestle_tick() -> void:
	var now := Sim.world.time
	var w: Dictionary = crew.get("wrestle", {})
	if w.is_empty():
		if now < _ring_free_at or not Sim.world.sub.is_surfaced():
			return
		var inside: Array[int] = []
		for p: Player in _players.get_children():
			if deck.in_ring(p.global_position):
				inside.append(p.peer_id)
		if inside.size() >= 2:
			inside.sort()
			crew.wrestle = Wrestling.new_bout(inside[0], inside[1], now)
			push_crew()
		return
	var gone: bool = not crew.names.has(w.a) or not crew.names.has(w.b) or not Sim.world.sub.is_surfaced()
	match String(w.phase):
		"count":
			var pa := _players.get_node_or_null(str(w.a)) as Player
			var pb := _players.get_node_or_null(str(w.b)) as Player
			if gone or pa == null or pb == null or not deck.in_ring(pa.global_position) or not deck.in_ring(pb.global_position):
				crew.erase("wrestle")
				push_crew()
			elif now >= w.until:
				_wrestle_phase(w, "choose", Wrestling.CHOOSE_TIME)
		"choose":
			if gone:
				crew.erase("wrestle")
				push_crew()
			elif w.moves.size() == 2 or now >= w.until:
				var r := Wrestling.resolve(w, w.moves.get("a", "brace"), w.moves.get("b", "brace"), crew_name(w.a), crew_name(w.b))
				w.pos += r.shift
				w.lock = r.lock
				w.off = r.off
				w.last = r.text
				_wrestle_phase(w, "show", Wrestling.SHOW_TIME)
		"show":
			if now >= w.until:
				var won := Wrestling.winner(w, deck.dims.ring_edge)
				if gone:
					crew.erase("wrestle")
					push_crew()
				elif won != 0:
					w.winner = won
					w.last = "%s\n%s goes over the side!" % [w.last, crew_name(w.b if won == w.a else w.a)]
					_wrestle_phase(w, "done", Wrestling.DONE_TIME)
				else:
					w.moves = {}
					_wrestle_phase(w, "choose", Wrestling.CHOOSE_TIME)
		"done":
			if now >= w.until:
				crew.erase("wrestle")
				_ring_free_at = now + 3.0
				push_crew()


func _wrestle_phase(w: Dictionary, phase: String, time: float) -> void:
	w.phase = phase
	w.until = Sim.world.time + time
	push_crew()


## A wrestler's secret move for this turn.
@rpc("any_peer", "call_local", "reliable")
func rq_wrestle(move: String) -> void:
	var w: Dictionary = crew.get("wrestle", {})
	if not multiplayer.is_server() or w.is_empty() or w.phase != "choose" or move not in Wrestling.MOVES:
		return
	if _sender() == w.a:
		w.moves.a = move
	elif _sender() == w.b:
		w.moves.b = move


## Host -> one player out on deck: she's going under, down the hatch with you.
@rpc("authority", "call_local", "reliable")
func send_below() -> void:
	if local_player != null and Deck.is_out(local_player.global_position):
		local_player.go_below()


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
		"realism": "arcade", ## a Realism key; set by the host
		"objectives": [], ## from the mission: each with "done", shown top right
		"sunk_by": {}, ## ship class key -> ships sunk
		"tutorial": {"step": 0, "course": Net.course}, ## course: a Tutorial.COURSES key
		"knocked": {}, ## peer -> seconds until they come round
		"suits": {}, ## peer -> true: wearing the boat's dive suit (Diving)
		"looks": {}, ## peer -> {hat, hue, rank} from their own profile
		"parts": sub_class.spare_parts, ## spare-parts boxes left in stores
		## The TDC: periscope marks on one target, the operator's nudges, and whether the
		## tubes' gyros follow its solution.
		"tdc": {"target": -1, "marks": [], "speed_adj": 0.0, "course_adj": 0.0, "follow": false},
		"plot": [], ## sonar bearings on the chart: {t, x, y (own position), b}
		"pencil": [], ## pencil marks on the chart: {x, y}
		## The deck gun: ready-use rounds at the gun, the rest in the magazine below; `next` is
		## the sim time it can fire again, `pass_next` when the next round can come up.
		"gun": {"ready": sub_class.gun_ready, "magazine": sub_class.gun_rounds - sub_class.gun_ready, "next": 0.0, "pass_next": 0.0},
	}


func _setup_mission() -> void:
	if crew.mission == "training":
		# Training plays at the host's level too, so Arcade teaches pointing the bow and
		# Standard/Realistic the TDC.
		Realism.apply(Sim.world, Net.realism)
		crew.realism = Sim.world.realism
		crew.tdc.follow = not Realism.uses_tdc(crew.realism)
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
	Sim.world.conditions.setup_weather(m.squalls, Sim.world.sub.pos, Sim.world.rng)
	Realism.apply(Sim.world, Net.realism)
	crew.realism = Sim.world.realism
	crew.tdc.follow = not Realism.uses_tdc(crew.realism) # Arcade: the tubes are always ready on the bow
	for g: Dictionary in m.groups:
		Formations.spawn(Sim.world, g)
	if m.sandbox:
		sandbox = Sandbox.new()
		sandbox.cold_war = m.era == "cold_war"
	crew.objectives = m.objectives.duplicate(true)
	for o: Dictionary in crew.objectives:
		o.done = false
	_lay_seabed()
	if m.limited_map:
		_limit_map.call_deferred()
	for i in Sim.world.rng.randi_range(2, 3):
		Sim.world.add_whale(Sim.world.rng.randf_range(1500.0, 6000.0))
	if Net.debug_reef:
		_debug_reef()
	if Net.debug_squall != "":
		var c := Sim.world.conditions
		c.squall_count = maxi(c.squall_count, 1)
		c.squalls.clear()
		c.add_squall(sub.pos + (sub.direction() * 4000.0 if Net.debug_squall == "ahead" else Vector2.ZERO), Sim.world.rng, 400.0)


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
	var m := MissionData.load_key(crew.mission)
	var size := Seabed.cave_size(sub_class.length, sub_class.beam, sub_class.height, sub_class.test_depth)
	if m != null:
		for k in m.deep_holes.size(): # the Titan's dives: the deep floor under her, and deeper still nearby
			var at := w.sub.pos + (Vector2.ZERO if k == 0 else Vector2.from_angle(k * 2.4) * 6000.0)
			w.seabed.features.append({"kind": "trench", "x": at.x, "y": at.y, "r": 3500.0, "top": m.deep_holes[k], "reef": 0.0, "ang": 0.0, "stretch": 1.0, "h": []})
	if m != null and m.cave: # the challenge: the cave's mouth dead ahead, she starts lined up on it
		var dir := w.sub.direction()
		var f := w.seabed.add_cave(w.sub.pos + dir * (CAVE_RUN_IN + 350.0), atan2(dir.y, dir.x), size)
		w.sub.depth = (Seabed.cave_roof(f, -350.0) + sub_class.height + Seabed.cave_bottom(f, -350.0)) * 0.5
		w.sub.ordered_depth = w.sub.depth
		w.sub.ballast = 1.0
	elif m != null and m.sandbox: # Blaney: caves hidden in the open sea too
		var at := w.sub.pos + Vector2.from_angle(w.rng.randf() * TAU) * w.rng.randf_range(7000.0, 14000.0)
		w.seabed.add_cave(at, w.rng.randf() * TAU, size)
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


## Testing aid (--test-breach): an emergency blow 3 s in; with --depth 80 she crash-surfaces.
func _debug_breach() -> void:
	await get_tree().create_timer(3.0).timeout
	Sim.world.sub.ballast_order("emergency")


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
	if Input.is_action_just_pressed("quit_to_menu") and not Net.dedicated:
		_quit("")
	if Net.dedicated and multiplayer.is_server() and not crew.is_empty():
		_serve(delta)
	if interior == null or crew.is_empty():
		return # a client still waiting to hear which boat this is
	_pick_music()
	_sweep_known(delta)
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
			"deep":
				progress = "  (%d m)" % roundi(Sim.world.sub.depth) if Sim.world != null and not o.get("done", false) else ""
			"survive", "cave":
				progress = "  (%s)" % OceanWorld.clock(Sim.world.time) if Sim.world != null else ""
				if o.kind == "cave" and Sim.world != null and Sim.world.cave_scrapes > 0:
					progress += "  scrapes: %d" % Sim.world.cave_scrapes
		lines.append("%s  %s%s" % ["✓" if o.get("done", false) else "○", o.text, progress])
	hud.set_objective(m.title.to_upper() + ("" if crew.get("realism", "arcade") == "arcade" else "  ·  " + Realism.level(crew.realism).title.to_upper()), ("\n".join(lines) + "\n\n" if not lines.is_empty() else "") + _skipper_orders() + crew_roles())


func _skipper_orders() -> String:
	var o: String = crew.get("orders", "")
	return "SKIPPER'S ORDERS\n%s\n\n" % o if o != "" else ""


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
	if crew.get("limited_map", false):
		known_sync.rpc_id(id, known.origin, known.grid)
	if not multiplayer.is_server():
		return
	print("%speer %d connected" % ["server: " if Net.dedicated else "", id])
	_spawner.spawn(_spawn_data(id))
	set_crew.rpc_id(id, crew)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var p := _players.get_node_or_null(str(id))
	if p != null:
		p.queue_free()
	if Net.dedicated:
		print("server: %s left (%d aboard)" % [crew_name(id), crew.names.size() - 1])
	crew.names.erase(id)
	crew.tools.erase(id)
	_clear_stations_of(id)
	push_crew()


## Every peer keeps the limited map up from the same replicated state; the host ends it (not on
## the fight-only patrol) once the enemy sub is gone.
func _sweep_known(delta: float) -> void:
	if not crew.get("limited_map", false) or Sim.world == null:
		return
	_known_timer -= delta
	if _known_timer > 0.0:
		return
	_known_timer = 1.0
	if known.grid.is_empty():
		known.start(Sim.world.sub.pos)
	known.sweep(Sim.world)
	if multiplayer.is_server() and not MissionData.load_key(crew.mission).limited_map \
			and not Sim.world.ships.any(func(s: ShipState) -> bool: return s.data.role == "sub" and not s.is_sinking()):
		crew.limited_map = false
		announce.rpc("Enemy sub's gone. The whole chart's back on the table.")
		push_crew()


## No soundtrack at sea (Blaney); the jukebox and anything else on it fall silent while anyone
## aboard plays an instrument. Every peer decides from its own players.
func _pick_music() -> void:
	if crew.result != "" or Sim.world == null:
		return
	Music.play(boat_music())
	Music.hush(band_playing())


func boat_music() -> String:
	return "typhoon" if sub_class != null and sub_class.key == "typhoon" else ""


func band_playing() -> bool:
	if crew.get("band", false) and TyphoonLayout.band_audible(crew):
		return true
	for p: Player in _players.get_children():
		if p.playing:
			return true
	return false


## Dedicated server: the boat waits while nobody is aboard; a finished patrol (90 s after the
## debrief) or one left empty for 10 minutes makes way for a fresh one.
const SERVER_DEBRIEF_TIME := 90.0
const SERVER_EMPTY_TIME := 600.0
var _server_idle := 0.0
var _had_crew := false ## someone has been aboard this patrol


func _serve(delta: float) -> void:
	var empty: bool = crew.names.is_empty()
	_had_crew = _had_crew or not empty
	if crew.result == "":
		Sim.running = not empty
	if crew.result != "" or (empty and _had_crew):
		_server_idle += delta
	else:
		_server_idle = 0.0
	var limit := SERVER_DEBRIEF_TIME if crew.result != "" else SERVER_EMPTY_TIME
	if crew.result != "" and not empty and int(_server_idle) == int(limit) - 30 and int(_server_idle - delta) != int(_server_idle):
		announce.rpc("A fresh patrol starts in 30 seconds. Join again to sail with it.")
	if _server_idle >= limit:
		print("server: starting a fresh patrol")
		for peer in multiplayer.get_peers():
			turned_away.rpc_id(peer, "That patrol is over; the server has started a new one. Join again to sail with it.")
		_server_idle = -INF # once
		get_tree().create_timer(1.0).timeout.connect(_restart_server) # let the goodbyes go out


func _restart_server() -> void:
	Net.stop()
	Net.mode = Net.Mode.HOST
	Sim.stop()
	get_tree().change_scene_to_file(get_tree().current_scene.scene_file_path)


## Back to the main menu (F10, or the pause menu).
func leave() -> void:
	_quit("")


## True while the pause menu is up: the local player's hands are off the controls.
func menu_open() -> bool:
	return (pause_menu != null and pause_menu.is_open) or bot_orders != null or pa_panel != null


## The orders panel for the bot at `station_id`.
func open_bot_orders(station_id: String) -> void:
	if bot_orders != null:
		bot_orders.close()
	bot_orders = BotOrders.new()
	bot_orders.station_id = station_id
	hud.add_child(bot_orders)


## The PA microphone's panel.
func open_pa() -> void:
	if pa_panel == null:
		pa_panel = PaPanel.new()
		hud.add_child(pa_panel)


func _quit(reason: String) -> void:
	Net.last_error = reason
	Net.stop()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU_SCENE)


# --- Crew state ------------------------------------------------------------

## Who sits at a pastime's seat, "" if nobody.
func _seated(id: String) -> String:
	return crew_name(station_occupant(id)) if station_occupant(id) != 0 else ""


func station_occupant(id: String) -> int:
	return crew.stations.get(id, 0)


func crew_name(id: int) -> String:
	if id < 0: # a bot crewman
		for b: Dictionary in crew.get("bots", {}).values():
			if int(b.id) == id:
				return b.name
	return crew.names.get(id, "Sailor %d" % id)


func push_crew() -> void:
	set_crew.rpc(crew)


@rpc("authority", "call_local", "reliable")
func set_crew(state: Dictionary) -> void:
	crew = state
	if not multiplayer.is_server() and Sim.world != null and Sim.world.realism != crew.get("realism", "arcade"):
		Realism.apply(Sim.world, crew.get("realism", "arcade")) # torpedo speed, handling for the client's view
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
		Music.hush(false)
		Music.play("menu", 4.0)
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
	var clean := {"hat": hat if Profile.HATS.has(hat) else "dixie", "hue": clampf(float(l.get("hue", -1.0)), -1.0, 1.0),
		"rank": clampi(int(l.get("rank", 0)), 0, Profile.RANKS.size() - 1)}
	# The face too (build, skin, hair, beard, extra): without it a crewman who joins shows up
	# with the default face, no pipe or cigarette, to everyone including himself.
	var sizes := {"build": Crewman.BUILDS.size(), "skin": Crewman.SKINS.size(), "hair": Crewman.HAIRS.size(),
		"hair_col": Crewman.HAIR_COLOURS.size(), "beard": Crewman.BEARDS.size(), "extra": Crewman.EXTRAS.size()}
	for k: String in sizes:
		clean[k] = clampi(int(l.get(k, 0)), 0, sizes[k] - 1)
	return clean


## Host -> one client: you can't join (different build).
@rpc("authority", "call_remote", "reliable")
func turned_away(reason: String) -> void:
	_quit(reason)


@rpc("authority", "call_local", "reliable")
func announce(text: String) -> void:
	hud.show_message(text)


## Host -> one crewman: a message just for him.
@rpc("authority", "call_local", "reliable")
func notice(text: String) -> void:
	hud.show_message(text, 4.0)


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
	if Net.dedicated:
		print("server: %s came aboard (%d aboard)" % [player_name.substr(0, 20), crew.names.size()])
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
	if station_id == "gun" and not Sim.world.sub.is_surfaced():
		notice.rpc_id(peer, "The hatch is shut: the gun can only be manned on the surface.")
		push_crew()
		return
	_clear_stations_of(peer)
	crew.stations[station_id] = peer
	push_crew()


## A crewman out on deck puts the dive suit on or takes it off, at the locker by the hatch (surfaced).
@rpc("any_peer", "call_local", "reliable")
func rq_suit(on: bool) -> void:
	if not multiplayer.is_server():
		return
	var peer := _sender()
	if not crew.has("suits"):
		crew.suits = {}
	if on:
		crew.suits[peer] = true
	else:
		crew.suits.erase(peer)
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


## Any crewman: post a bot to a station, stand one down, or give one orders (BotCrew).
@rpc("any_peer", "call_local", "reliable")
func rq_bot(station_id: String, key: String, value: Variant) -> void:
	if multiplayer.is_server():
		bot_crew.request(station_id, key, value)


## Any crewman: a line into the PA. The crew do what it says (BotCrew).
@rpc("any_peer", "call_local", "reliable")
func rq_pa(text: String) -> void:
	if multiplayer.is_server() and crew.get("result", "") == "":
		bot_crew.skipper_order(text.left(160), crew_name(_sender()), _sender())


## The skipper's words over the speakers, for everyone.
@rpc("authority", "call_local", "reliable")
func pa_call(who: String, text: String) -> void:
	hud.crew_call(who, text)


## "enemy sub" on the PA (Blaney): starts a fight with one somewhere close, or goes after the one
## we have. The map goes dark for as long as it lasts.
func call_enemy_sub(attack: bool) -> String:
	var w := Sim.world
	var live: Array = w.ships.filter(func(s: ShipState) -> bool: return s.data.role == "sub" and not s.is_sinking())
	if not live.is_empty():
		if attack and bot_crew.find_target("sub", {}) != null:
			return bot_crew._carry_out({"intent": "attack", "target": "sub", "dir": {}})
		return "There's one out there already, Skipper. Listen for it."
	var at := w.sub.pos
	for i in 40:
		at = w.sub.pos + Vector2.from_angle(w.rng.randf() * TAU) * w.rng.randf_range(3000.0, 5500.0)
		if w.seabed.floor_depth(at) > 90.0:
			break
	Formations.enemy_sub(w, at, ShipState.bearing(at, w.sub.pos), 4.0, enemy_sub_class())
	if not crew.objectives.is_empty(): # the open patrol has none: one here would end it
		crew.objectives.append({"kind": "sink_class", "class": enemy_sub_class(), "count": 1, "text": "Sink the enemy sub (bonus)", "bonus": true, "done": false})
	_limit_map()
	return "Enemy sub reported close by, Skipper. Rig for quiet: from here on the chart's only what we can see."


## A monster on the PA (Blaney: "a command in the PA to spawn one"): one of the things from the
## depths, close by and below, coming for us. It only comes as shallow as its own depth.
func call_monster(kind: String) -> String:
	var w := Sim.world
	for m in w.monsters:
		if not m.is_dead() and m.pos.distance_to(w.sub.pos) < 4000.0:
			return "There's already something out there, Skipper. The %s. Listen." % m.info().name
	var m := w.add_monster(kind, 900.0, true)
	if w.sub.depth < m.floor_depth() - 20.0:
		return "Something's down there, Skipper... a %s, deep. It won't come above %d metres: take her down if you want it." % [m.info().name, roundi(m.floor_depth())]
	return "Sonar: something's moving down there, Skipper. Something big. A %s... and it's coming for us." % m.info().name


func enemy_sub_class() -> String:
	return "los_angeles" if sub_class.era == "cold_war" else "i_boat"


## From now on the chart and sand table only show what the boat has seen.
func _limit_map() -> void:
	crew.limited_map = true
	known.start(Sim.world.sub.pos)
	known.sweep(Sim.world)
	known_sync.rpc(known.origin, known.grid)
	push_crew()


## Host -> everyone: the host's picture of the map, on starting a fight or on joining one.
@rpc("authority", "call_remote", "reliable")
func known_sync(origin: Vector2, grid: PackedByteArray) -> void:
	known.origin = origin
	known.grid = grid
	known.version += 1


## The skipper's word to the band (Blaney: a good part of a Typhoon's crew plays whatever's on).
func call_band(off: bool) -> String:
	if sub_class.key != "typhoon":
		return "We haven't the hands to spare for a band on this boat, Skipper."
	crew.band = not off
	if off:
		return "Back to your posts, lads."
	crew.full_crew = true
	var rec: Array = Jukebox.RECORDS[int(crew.get("jukebox", 0)) % Jukebox.RECORDS.size()]
	return "Forty hands to the rec room, Skipper. %s." % ("The Foggy Dew" if rec[1] == "" or rec[1] == "foggy_dew" else "Playing along with \"%s\"" % rec[0])


## A crewman out on deck lands a fish (Pastimes.FISH index, kg).
@rpc("any_peer", "call_local", "reliable")
func rq_fish(kind: int, kg: float) -> void:
	if not multiplayer.is_server():
		return
	var said := Pastimes.landed(crew, crew_name(_sender()), kind, kg)
	if said != "":
		announce.rpc(said)
		push_crew()


## Any crewman: the jukebox's next record.
@rpc("any_peer", "call_local", "reliable")
func rq_jukebox() -> void:
	if not multiplayer.is_server():
		return
	crew.jukebox = (int(crew.get("jukebox", 0)) + 1) % Jukebox.RECORDS.size()
	push_crew()


## Host: the deck gun fires a round on true bearing `brg` set for `range_m`, if she is on the
## surface, has a round at the gun and is ready again.
func _fire_gun(brg: float, range_m: float) -> void:
	var gun: Dictionary = crew.gun
	var w := Sim.world
	if not w.sub.is_surfaced() or int(gun.ready) <= 0 or w.time < float(gun.next):
		return
	gun.ready = int(gun.ready) - 1
	gun.next = w.time + sub_class.gun_reload
	w.fire_gun(brg, clampf(range_m, 200.0, sub_class.gun_range), sub_class.gun_damage)
	if int(gun.ready) == 0:
		announce.rpc("Gun: out of ready rounds! %s" % ("Pass ammunition up (ammo scuttle, %s)." % interior.stations.ammo.get_meta("where") if int(gun.magazine) > 0 else "The magazine's empty."))
	push_crew()


## Host: the ammunition party passes one round up from the magazine to the gun.
func _pass_ammo() -> void:
	var gun: Dictionary = crew.gun
	var w := Sim.world
	if int(gun.magazine) <= 0 or int(gun.ready) >= sub_class.gun_ready or w.time < float(gun.pass_next):
		return
	gun.magazine = int(gun.magazine) - 1
	gun.ready = int(gun.ready) + 1
	gun.pass_next = w.time + PASS_TIME
	push_crew()


@rpc("any_peer", "call_local", "reliable")
func rq_order(station_id: String, key: String, value: Variant) -> void:
	if not multiplayer.is_server() or station_occupant(station_id) != _sender():
		return
	apply_order(station_id, key, value, _sender())


## Host: an order at a station from whoever mans it, a player or a bot (`by`).
func apply_order(station_id: String, key: String, value: Variant, by: int) -> void:
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
			elif key == "depth" and sub_class.fragile: # the Titan's pilot does it all
				sub.ordered_depth = clampf(float(value), 0.0, sub.data.crush_depth)
			elif key == "weights" and sub_class.fragile:
				sub.ballast_order("emergency")
				_surface_order()
				announce.rpc("Pilot: weights away! She's going up.")
		"dive":
			if key == "depth":
				if float(value) > 0.0 and _deck_blocks_dive():
					push_crew()
					return
				sub.ordered_depth = clampf(float(value), 0.0, sub.data.crush_depth) # down to where she breaks (Blaney: scary deep)
				# Surface on the planes alone leaves her awash with the tanks full and the hatch
				# shut, so the order to surface blows main ballast too (Blaney: "i cannot open the
				# hatch even though i pressed 1 to surface").
				if sub.ordered_depth <= 0.0 and sub.ballast > 0.0 and sub.blowing == 0 and not sub_class.fragile:
					sub.ballast_order("blow")
			if key == "party":
				bot_crew.send_party()
				announce.rpc("First mate: damage parties, turn to!")
		"holo":
			crew.holo = not crew.get("holo", false)
			announce.rpc("Skipper: %s" % ("hologram on." if crew.holo else "hologram off."))
			push_crew()
		"skipper":
			if key == "read":
				crew.mate_read = crew.get("mate_news", 0)
				push_crew()
		"periscope":
			if key == "raised":
				sub.periscope_raised = bool(value)
			elif key == "ranged" and tutorial != null:
				tutorial.flag("ranged")
			elif key == "mark" and value is Array and value.size() == 3:
				_tdc_mark(int(value[0]), float(value[1]), float(value[2]))
		"tdc":
			if arcade_aim():
				notice.rpc_id(_sender(), "Arcade: no TDC. Point the bow at the periscope's mark and fire.")
				return
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
				if key == "vent" and _deck_blocks_dive():
					push_crew()
					return
				sub.ballast_order(key)
				if key in ["blow", "emergency"]:
					_surface_order() # or the planesman and the ballast bot take her straight back down
				if key == "emergency" and sub.blowing == 2:
					announce.rpc("EMERGENCY BLOW! All main ballast tanks blowing.")
		"bilge":
			if key == "pump":
				Sim.world.hull.bilge_on = bool(value) and sub.battery > 0.0
		"gun":
			if key == "fire" and value is Array and value.size() == 2:
				_fire_gun(float(value[0]), float(value[1]))
		"ammo":
			if key == "pass":
				_pass_ammo()
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
		"darts":
			if key == "score":
				var best: Dictionary = crew.get_or_add("darts", {})
				var who := crew_name(by)
				if int(value) > int(best.get(who, -1)):
					best[who] = clampi(int(value), 0, 180)
				announce.rpc("%s throws %d%s" % [who, int(value), "  — ONE HUNDRED AND EIGHTY!" if int(value) == 180 else ""])
		"arm_a", "arm_b":
			if key == "push":
				Pastimes.arm_push(crew, station_id, int(value))
		"cards_1", "cards_2":
			var said := Pastimes.cards_order(crew, station_id, String(key), crew_name(by), _fun_rng)
			if said != "":
				announce.rpc(said)
		"galley":
			if key == "meal":
				announce.rpc(Pastimes.meal(crew, crew_name(by), int(value)))
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
## Arcade aims by pointing the bow (Blaney); Standard and Realistic use the TDC and gyros.
func arcade_aim() -> bool:
	return not Realism.uses_tdc(crew.get("realism", "arcade"))


func tdc_solution(stern := false) -> Dictionary:
	if Sim.world != null and arcade_aim():
		return Sim.world.arcade_solution(stern)
	var tdc: Dictionary = crew.get("tdc", {})
	if Sim.world == null or tdc.get("marks", []).is_empty():
		return {"ok": false, "reason": "NO MARKS", "est": {"ok": false}}
	var sub := Sim.world.sub
	var est := Tdc.estimate(tdc.marks, tdc.speed_adj, tdc.course_adj)
	var launch := sub.pos + sub.direction() * sub.data.length * (-0.5 if stern else 0.5)
	var sol := Tdc.solve(est, Sim.world.time, launch, fposmod(sub.heading + (180.0 if stern else 0.0), 360.0), Sim.world.torpedo_speed)
	sol.est = est
	sol.quality = Tdc.quality(tdc.marks, sol.range)
	return sol


## Host: tubes whose gyros follow the TDC get the new angle as it changes.
func _tdc_follow() -> void:
	if not crew.tdc.follow or arcade_aim():
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
			if arcade_aim():
				return
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
				if arcade_aim():
					Sim.world.fire_torpedo(0.0, t.get("stern", false))
					announce.rpc("Tube %d fired!" % (i + 1))
				else:
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
	if Tools.is_instrument(kind) and crew.tools.values().has(kind):
		return # one of each instrument aboard, and someone has it
	if kind == "":
		crew.tools.erase(peer)
	elif Tools.exists(kind):
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
	hull.pumps.append({"c": hull.comp_at_pos(pos), "p": Vector3(pos.x, maxf(pos.y, 0.0), pos.z)})
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


## A blow is an order to surface: the ordered depth goes to the surface and so does the bot
## planesman's (off his own initiative), so nobody floods her back down and the hatch opens once she's up (Blaney: "it
## was staying locked even though we were surfaced").
func _surface_order() -> void:
	Sim.world.sub.ordered_depth = 0.0
	var b: Dictionary = crew.get("bots", {}).get("dive", {})
	if not b.is_empty():
		b.depth = 0.0
		b.auto = false # his own idea of a depth would take her back down


func end_patrol(result: String, text: String) -> void:
	if crew.result != "":
		return
	if Net.dedicated:
		print("server: patrol over: %s. %s" % [result, text])
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
	_wrestle_tick()
	var said := Pastimes.arm_step(crew, _seated(Pastimes.ARM[0]), _seated(Pastimes.ARM[1]), Sim.world.time)
	if said != "":
		announce.rpc(said)
		push_crew()
	elif crew.get("arm", {}).get("on", false):
		_arm_push_timer -= delta
		if _arm_push_timer <= 0.0: # the hands move: let everyone see it a few times a second
			_arm_push_timer = 0.15
			push_crew()
	if not sub.is_surfaced(): # going under anyway (flooding): everyone on deck without a suit down the hatch
		for p: Player in _players.get_children():
			if Deck.is_out(p.global_position) and not Diving.suited(p.peer_id) and not p.godly():
				send_below.rpc_id(p.peer_id)
	if station_occupant("gun") > 0 and not sub.is_surfaced():
		crew.stations.erase("gun")
		announce.rpc("Clear the deck! The gun crew tumbles down the hatch.")
		push_crew()
	_breathe(delta)
	_tdc_follow()
	_lookouts()
	_weather_calls()
	if sandbox != null:
		sandbox.tick(Sim.world, delta)
	_check_patrol_complete(delta)
	var reloading := false
	for i in crew.tubes.size():
		var t: Dictionary = crew.tubes[i]
		if t.reload > 0.0 and station_occupant("tube_%d" % (i + 1)) != 0:
			reloading = true
			# A small crew has its hands full: reloads go a little quicker with fewer aboard.
			# A second pair of hands on the hoist (a crewmate standing by, off station) makes
			# it go faster still (design: "2 people faster").
			var helped := _reload_helper(i)
			if helped != t.get("helped", false):
				t.helped = helped
				push_crew()
			t.reload += delta * (HELP_RELOAD if helped else 1.0) / (RELOAD_TIME * clampf(0.6 + 0.1 * crew.names.size(), 0.8, 1.2))
			if t.reload >= 1.0:
				t.reload = 0.0
				t.helped = false
				t.loaded = true
				announce.rpc("Tube %d loaded." % (i + 1))
				push_crew()
	if reloading:
		_push_timer += delta
		if _push_timer > 0.25:
			_push_timer = 0.0
			push_crew()


## Whether a crewmate off station stands within reach of tube `i` to help the reload.
func _reload_helper(i: int) -> bool:
	var st: Station = interior.stations.get("tube_%d" % (i + 1))
	var working := station_occupant("tube_%d" % (i + 1))
	var on_station: Array = crew.get("stations", {}).values()
	for p: Player in _players.get_children():
		if p.peer_id != working and not on_station.has(p.peer_id) and Vector2(p.global_position.x - st.global_position.x, p.global_position.z - st.global_position.z).length() < HELP_REACH:
			return true
	return false


## Surfaced, the lookouts call any plane within 7 km (by day; 2 km at night).
func _lookouts() -> void:
	var w := Sim.world
	if not w.sub.is_surfaced():
		return
	var r := 7000.0 * (0.3 if w.conditions.night else 1.0) * lerpf(1.0, Conditions.RAIN_SIGHT, w.conditions.rain_at(w.sub.pos))
	for p in w.planes:
		if not _planes_called.has(p.id) and p.pos.distance_to(w.sub.pos) < r:
			_planes_called[p.id] = true
			announce.rpc("AIRCRAFT, bearing %03d! Clear the bridge — DIVE, DIVE!" % (roundi(ShipState.bearing(w.sub.pos, p.pos)) % 360))
			alarm.rpc()


## The lookouts call it when a squall comes over the boat, and when it clears (only near the
## surface: deep down nobody sees the sky).
func _weather_calls() -> void:
	var w := Sim.world
	var rain := w.conditions.rain_at(w.sub.pos)
	var near_top := w.sub.depth <= w.sub.data.periscope_depth + 2.0
	if not _in_rain and rain > 0.5 and near_top:
		_in_rain = true
		announce.rpc("Rain squall over us! The lookouts can't see a mile, and neither can theirs: good cover to close in.")
	elif _in_rain and rain < 0.15:
		_in_rain = false
		if near_top:
			announce.rpc("We're out of the rain. They can see us again.")


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
		if crew.get("god", {}).has(peer): # god mode: nothing knocks him out
			continue
		if crew.knocked.has(peer):
			crew.knocked[peer] -= delta
			if crew.knocked[peer] <= 0.0:
				crew.knocked.erase(peer)
				_exposure.erase(peer)
				wake_at.rpc_id(peer, _best_air_spot())
				changed = true
			continue
		var bad := w.air.badness_in(w.hull.comp_at_pos(p.global_position))
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
	return Vector3(float(c.get("x", 0.0)) + randf_range(-0.5, 0.5), float(c.get("y", 0.0)) + 0.1, (c.z0 + c.z1) * 0.5 + randf_range(-1.0, 1.0))


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
	var cave := false
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
			"cave":
				o.done = w.caves_through >= 1
				cave = cave or o.done
			"deep":
				o.done = o.done or w.sub.depth >= float(o.value) or (w.sub.depth > float(o.value) * 0.9 and w.seabed.floor_depth(w.sub.pos) - w.sub.depth < 3.0)
			"surface":
				var rest: bool = crew.objectives.all(func(x: Dictionary) -> bool: return x.kind == "surface" or x.done)
				o.done = rest and w.sub.depth <= 5.0
				cave = cave or o.done
		changed = changed or was != o.done
		if not o.done and not o.get("bonus", false):
			all_done = false
	if changed:
		push_crew()
	if all_done and survive:
		end_patrol("complete", "They gave up the hunt. We made it.")
		return
	if all_done and cave:
		var hits := w.cave_scrapes
		var how := "not a scratch on her" if hits == 0 else "%d scrape%s" % [hits, "" if hits == 1 else "s"]
		if w.caves_through == 0:
			end_patrol("complete", "Down to the bottom and back up in %s. The hull monitor peaked at %d%%." % [OceanWorld.clock(w.time), roundi(w.hull_strain * 100.0)])
		else:
			end_patrol("complete", "Through the cave in %s, %s." % [OceanWorld.clock(w.time), how])
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


## A thing from the depths (Monster) does something: what the crew hears and feels of it, and
## (host) what's called out. Creepy dread, no gore (Blaney): a groaning call through the hull,
## the frames creaking as it squeezes, a great thump and the lights going when it strikes.
func _monster_event(d: Dictionary) -> void:
	var near := Vector2(d.x, d.y).distance_to(Sim.world.sub.pos) < 1200.0
	var trauma := 0.0
	match String(d.act):
		"call", "charge":
			if near or d.act == "charge":
				_monster_call(-4.0 if d.act == "charge" else -12.0)
		"grab", "squeeze":
			Sfx.play("creak_%d" % randi_range(1, 3), 4.0, 0.4)
			Sfx.play("creak_%d" % randi_range(1, 3), 0.0, 0.55)
			trauma = 0.55 if d.act == "grab" else 0.3
		"bite", "strike", "ram":
			Sfx.play("torpedo_hit", 2.0, 0.45)
			Sfx.play("clang", 0.0, 0.5)
			trauma = 0.9 if d.act == "ram" else 0.65
		"hurt", "dead":
			_monster_call(-2.0, 0.5)
	if trauma > 0.0:
		if local_player != null:
			local_player.add_trauma(trauma)
		interior.flicker(trauma)
		interior.shake_loose(trauma * 0.8)
	if not multiplayer.is_server():
		return
	var lines: Array[String] = []
	match String(d.act):
		"charge":
			lines.append("Sonar: something huge, coming in fast... it's not a ship!")
		"grab":
			lines.append("Something's got hold of the hull! The %s is wrapped round us!" % d.name)
		"bite":
			lines.append("The %s bit into the hull!" % d.name)
		"strike":
			lines.append("The %s struck the hull!" % d.name)
		"ram":
			lines.append("The %s rammed us!" % d.name)
		"release":
			lines.append("It's let go... it's gone back into the dark.")
		"hurt":
			lines.append("HIT! The %s thrashes off into the deep." % d.name)
		"dead":
			lines.append("The %s is dead. It sinks away into the black." % d.name)
		"give_up":
			lines.append("Sonar: it's not following us up. It's going back down.")
	for m: String in d.get("dmg", []):
		if m.begins_with("BROKEN:"):
			var st: Station = interior.stations.get(m.trim_prefix("BROKEN:"))
			lines.append("%s knocked out!" % (st.display_name if st != null else "Equipment"))
		else:
			lines.append(m)
	if not lines.is_empty():
		announce.rpc("  ".join(lines))
		push_crew()


## Its call through the hull: the whale's song slowed to a groan, fading out.
func _monster_call(db: float, pitch := 0.32) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = Sfx.stream("whale_loop")
	p.bus = "Effects"
	p.volume_db = db
	p.pitch_scale = pitch * randf_range(0.9, 1.1)
	add_child(p)
	p.play(randf_range(0.0, 4.0))
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -50.0, 7.0).set_delay(2.0)
	tw.tween_callback(p.queue_free)


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
			Sfx.play("sonar_ping", 0.0, 0.72 if sub_class.nuclear else 1.0)
		"gun":
			var on_gun := local_player != null and local_player.station != null and local_player.station.station_id == "gun"
			Sfx.play("deck_gun", 0.0 if on_gun else -12.0, randf_range(0.95, 1.05)) # muffled through the hull below
		"gun_hit":
			var watching := local_player != null and local_player.station != null and local_player.station.station_id in ["gun", "periscope"]
			if watching:
				Sfx.play("shell_hit", -14.0, 0.6) # far off, a flat bang
		"fired":
			Sfx.play("torpedo_launch")
		"hit", "beached":
			Sfx.play("torpedo_hit")
		"crack": # the carbon going: sharp cracks, louder each time
			Sfx.play("clang", -6.0 + 4.0 * float(data.level), 1.6)
			Sfx.play("creak_%d" % randi_range(1, 3), 2.0 * float(data.level), 1.3)
		"implode":
			Sfx.play("torpedo_hit", 8.0, 0.7)
		"grounded":
			Sfx.play("clang", 4.0 if data.hard else -2.0, 0.6)
			Sfx.play("creak_%d" % randi_range(1, 3), 0.0, 0.7)
		"sunk":
			Sfx.play("creak_%d" % randi_range(1, 3), -4.0, 0.5) # breaking up


func _on_sim_event(kind: String, data: Dictionary) -> void:
	_event_sound(kind, data)
	if kind == "monster":
		_monster_event(data)
	if kind == "own_ping" and crew.get("limited_map", false):
		known.reveal(Sim.world.sub.pos, ChartKnown.PING_RANGE, ChartKnown.SONAR)
	if kind == "enemy_torpedo" and multiplayer.is_server():
		announce.rpc("Sonar: TORPEDO IN THE WATER, bearing %03d!" % (roundi(float(data.b)) % 360))
		alarm.rpc()
	if kind == "dud_on_us":
		announce.rpc("Something hit the hull... and didn't go off!") if multiplayer.is_server() else null
	if kind == "hit" or kind == "beached":
		exterior.explosion(Vector2(data.x, data.y))
	elif kind == "breach": # crash surface: the bow leaps out and slams down, everyone thrown about
		var p: float = data.p
		exterior.water_column(Vector2(data.x, data.y), 14.0 * p)
		Sfx.play("splash", 0.0, 0.7)
		if local_player != null:
			local_player.add_trauma(p)
			get_tree().create_timer(2.0).timeout.connect(func() -> void:
				if is_instance_valid(local_player):
					local_player.add_trauma(p) # the slam
					Sfx.play("splash", 2.0, 0.55))
		interior.shake_loose(p)
		interior.flicker(p * 0.8)
		if multiplayer.is_server():
			announce.rpc("Control: CRASH SURFACE! Hold on!")
	elif kind == "crack" and local_player != null:
		local_player.add_trauma(0.2 * float(data.level))
		interior.flicker(0.3 * float(data.level))
	elif kind == "implode" and local_player != null:
		local_player.add_trauma(1.0)
		interior.flicker(1.0)
	elif kind == "grounded" and local_player != null:
		local_player.add_trauma(0.8 if data.hard else 0.3)
	elif kind == "shell":
		exterior.water_column(Vector2(data.x, data.y), 4.0)
	elif kind == "gun":
		exterior.gun_fired()
		if local_player != null and local_player.station != null and local_player.station.station_id == "gun":
			local_player.add_trauma(0.25)
	elif kind == "gun_splash":
		exterior.shell_splash(Vector2(data.x, data.y))
	elif kind == "gun_hit":
		exterior.shell_burst(Vector2(data.x, data.y))
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
		"track_spotted":
			# Sonar hears it: screws speeding up and turning toward us.
			announce.rpc("Sonar: the %s's speeding up, turning down our torpedo track!" % data.name)
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
		"leak", "power", "breakdown", "grounded", "cave_through", "crack":
			announce.rpc(data.text)
			push_crew()
		"beached":
			announce.rpc("A torpedo ran into the shallows and went off.")
		"lost":
			end_patrol("lost", data.reason)
		"hit":
			if not data.get("monster", false):
				announce.rpc("HIT! %s" % data.name)
		"gun_hit":
			var ship := Sim.world.find_ship(int(data.ship))
			if ship != null and not ship.is_sinking():
				announce.rpc("Gun: a hit on the %s!" % data.name)
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
