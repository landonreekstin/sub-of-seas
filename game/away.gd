class_name Away
extends Node3D
## Away from the boat (Blaney: "get to land on inflatable rafts, add walkable beaches on land"):
## the life rafts (Raft, launched from the locker on deck) and walking ashore.
##
## Like the deck (Deck), both are places far up in the interior's space where nothing of the boat
## is, so the crewman's own node can stand somewhere: in a raft he is parked, seated, at
## RAFT_PARK (one spot a raft, so a raft's crew hear each other talk), and what he sees is the
## exterior ocean through an eye on the raft. Ashore he walks on a copy of the island's ground,
## built as collision round ASHORE in the island's own space (exterior space less its centre),
## and the exterior camera follows his eye there. The rafts are in the sim (host-run, replicated);
## who is ashore on which island is crew state (`crew.ashore`).

const RAFT_PARK := Vector3(0, 12000, 0)
const ASHORE := Vector3(0, 20000, 0)
const MAX_RAFTS := 2 ## out of the locker at once: two four-man rafts carry a full crew
const REACH := 5.0 ## m from a raft you can climb into her
const STOW_NEAR := 30.0 ## m: an empty raft this close to her is hauled in and stowed...
const STOW_AFTER := 15.0 ## ...after this long empty
const WADE := -1.0 ## m: ashore, you wade no deeper than this (the sea's floor is not for walking)
const SWIM_OFF := 35.0 ## m past her hull a man in a raft can still swim back to her

var _models := {} ## raft id -> RaftModel (in the exterior)
var _figures := {} ## peer id -> {node, look, ashore}
var _sounds := {} ## raft id -> AudioStreamPlayer (the rocket)
var _hop := {} ## raft id -> her hop last frame (a slap when she comes down)
var _mode := "" ## "", "raft" or "ashore"
var _view: CanvasLayer
var _sea: AudioStreamPlayer
var _ground: StaticBody3D
var _ground_island := -1
var _last_dry := Vector3.ZERO
var _left_at := -10.0 ## when we got out of a raft (until the host's word that we have)
var _sent := Vector3(INF, INF, INF)
var _send_timer := 0.0
var _paddle_t := 0.0


static func is_rafting(p: Vector3) -> bool:
	return p.y > RAFT_PARK.y - 1000.0 and p.y < RAFT_PARK.y + 1000.0


static func is_ashore(p: Vector3) -> bool:
	return p.y > ASHORE.y - 1000.0


static func is_away(p: Vector3) -> bool:
	return p.y > 9000.0


## The island feature nearest to `p` (sim metres), or -1.
static func nearest_island(seabed: Seabed, p: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in seabed.features.size():
		var f: Dictionary = seabed.features[i]
		if f.kind != "island":
			continue
		var d := p.distance_to(Vector2(f.x, f.y)) - float(f.r) * float(f.stretch)
		if d < best_d:
			best_d = d
			best = i
	return best


static func island_centre(island: int) -> Vector2:
	var f: Dictionary = Sim.world.seabed.features[island]
	return Vector2(f.x, f.y)


## Where a point ashore (interior space) is in the sim (x east, y north).
static func ashore_to_world(island: int, p: Vector3) -> Vector2:
	var local := p - ASHORE
	return island_centre(island) + Vector2(local.x, -local.z)


## Where this crewman is in the sim, if he's out of the boat at all (deck, sea, raft, ashore);
## else INF.
static func world_pos(player: Player) -> Vector2:
	var p := player.global_position
	if Deck.is_out(p):
		return Diving.world_of(Sim.world.sub, p - Deck.ORIGIN)
	if is_ashore(p):
		var island: int = Game.instance.crew.get("ashore", {}).get(player.peer_id, -1)
		return ashore_to_world(island, p) if island >= 0 else Vector2.INF
	var r := Sim.world.raft_of(player.peer_id)
	return r.pos if r != null else Vector2.INF


var _debug_t := 0.0


## Testing aid (--raft [sea|rocket|beach]): the host, surfaced, in a raft alongside her; with the
## rocket fitted; or on a beach, out of the raft.
func _debug(me: Player, delta: float) -> void:
	_debug_t += delta
	var g := Game.instance
	var w := Sim.world
	if _debug_t < 1.0:
		return
	if w.rafts.is_empty():
		w.sub.depth = 0.0
		w.sub.ordered_depth = 0.0
		w.sub.telegraph = 0 # stopped, so she doesn't sail off and leave the raft behind
		w.sub.speed = 0.0
		g.rq_raft_launch()
		return
	var r := w.rafts[0]
	if r.seat_of(me.peer_id) < 0 and not is_ashore(me.global_position):
		g.rq_raft_board(r.id)
		if Net.debug_raft == "rocket":
			g.rq_raft_rocket(r.id)
		elif Net.debug_raft == "beach":
			var island := nearest_island(w.seabed, r.pos)
			var f: Dictionary = w.seabed.features[island]
			var c := Vector2(f.x, f.y)
			var out := (w.sub.pos - c).normalized()
			var p := c
			while w.seabed.floor_depth(p) < 0.0:
				p += out * 2.0
			r.pos = p - out * 4.0
			r.heading = fposmod(rad_to_deg(atan2(-out.x, -out.y)), 360.0)
		return
	if Net.debug_raft == "beach" and _debug_t > 2.5 and _mode == "raft":
		get_out(r)
		me.rotation.y += PI # looking back out to sea, the raft on the sand
	if _debug_t > 3.0:
		Net.debug_raft = ""


func _process(delta: float) -> void:
	if Sim.world == null or Game.instance.exterior == null:
		return
	var me := Game.instance.local_player
	if Net.debug_raft != "" and me != null and multiplayer.is_server():
		_debug(me, delta)
	_sync_models(delta, me)
	if me == null:
		return
	var r := Sim.world.raft_of(me.peer_id)
	var mode := ""
	if r != null and Sim.world.time - _left_at > 1.0:
		mode = "raft"
	elif is_ashore(me.global_position):
		mode = "ashore"
	if mode != _mode:
		_switch(mode)
	var ext := Game.instance.exterior
	if mode == "raft":
		var seat := r.seat_of(me.peer_id)
		var park := RAFT_PARK + Vector3(r.id * 40.0, 0.0, 0.0) + RaftModel.SEATS[seat]
		if me.global_position.distance_to(park) > 0.5:
			me.global_position = park
			me.velocity = Vector3.ZERO
		ext.world_eye = RaftModel.sea_transform(r) * RaftModel.seat_eye(seat, me.rotation.y, me.head.rotation.x)
		_raft_controls(r, seat, me, delta)
	elif mode == "ashore":
		var island: int = Game.instance.crew.get("ashore", {}).get(me.peer_id, -1)
		if island >= 0 and island < Sim.world.seabed.features.size():
			if island != _ground_island:
				_build_ground(island)
			var eye := me.camera.global_transform
			eye.origin += ExteriorWorld.to_3d(island_centre(island)) - ASHORE
			ext.world_eye = eye


func _physics_process(_delta: float) -> void:
	var me := Game.instance.local_player if Game.instance != null else null
	if me == null or _mode != "ashore":
		return
	# Wading is as far as it goes: the sea floor off the beach isn't for walking on.
	if me.global_position.y - ASHORE.y < WADE:
		me.global_position = _last_dry
		me.velocity = Vector3.ZERO
	else:
		_last_dry = me.global_position


func _switch(mode: String) -> void:
	_mode = mode
	var ext := Game.instance.exterior
	var on := mode != ""
	if on:
		ext.eye_mode = "world"
		ext.set_active(true)
		if _view == null:
			_view = CanvasLayer.new()
			_view.layer = -1
			var tex := TextureRect.new()
			tex.texture = ext.viewport.get_texture()
			tex.set_anchors_preset(Control.PRESET_FULL_RECT)
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_view.add_child(tex)
			add_child(_view)
			_sea = AudioStreamPlayer.new()
			_sea.stream = Sfx.stream("sea_loop")
			_sea.bus = "Effects"
			_sea.volume_db = -8.0
			add_child(_sea)
			_sea.play()
		if mode == "raft":
			Game.instance.local_player.rotation.y = 0.0 # facing her bow
	else:
		if _view != null:
			_view.queue_free()
			_view = null
		if _sea != null:
			_sea.queue_free()
			_sea = null
		Game.instance.hud.set_prompt("")
		if ext.eye_mode == "world": # the deck takes it back if that's where we are
			ext.eye_mode = "scope"
			ext.set_active(false)
	if mode != "ashore" and _ground != null:
		_ground.queue_free()
		_ground = null
		_ground_island = -1


## In a raft: W/S paddle (the driver, with the rocket fitted: the throttle), A/D steer, R the
## rocket in or out of its compartment (driver), Q get out.
func _raft_controls(r: Raft, seat: int, me: Player, delta: float) -> void:
	var hud := Game.instance.hud
	if Game.instance.menu_open() or me.is_knocked_out():
		return
	var fwd := Input.get_axis("move_back", "move_forward")
	var steer := Input.get_axis("move_left", "move_right")
	var now := Vector3(fwd, steer, 0.0)
	_send_timer -= delta
	if now != _sent or _send_timer <= 0.0:
		_sent = now
		_send_timer = 0.5
		Game.instance.rq_raft_input.rpc_id(1, r.id, fwd, steer)
	if seat == 0 and Input.is_action_just_pressed("lifeline"):
		Game.instance.rq_raft_rocket.rpc_id(1, r.id)
	if Input.is_action_just_pressed("leave_station"):
		get_out(r)
		return
	var keys := ""
	if seat == 0 and r.rocket:
		keys = "W rocket  S brake  A/D tiller  R stow the rocket  Q get out"
	elif seat == 0:
		keys = "W/S paddle  A/D steer  R fit the rocket  Q get out"
	else:
		keys = "W/S paddle%s  Q get out" % ("" if r.crew[0] != 0 else "  A/D steer")
	var speed := ""
	if absf(r.speed) > 0.5:
		speed = "  —  %d mph" % roundi(absf(r.speed) * 2.237)
	hud.set_prompt("%s%s\n%s" % ["DRIVING THE RAFT" if seat == 0 else "IN THE RAFT", speed, keys])
	# Paddling: a stroke's splash now and then.
	if not r.rocket and absf(fwd) > 0.1 and r.ground <= -Raft.LAND:
		_paddle_t -= delta
		if _paddle_t <= 0.0:
			_paddle_t = randf_range(0.9, 1.3)
			Sfx.play("splash", -20.0, randf_range(1.3, 1.6))


## Out of the raft: onto the beach if she's in the shallows or up on the sand, into the sea
## alongside the boat if she's close, else it's too far to swim.
func get_out(r: Raft) -> void:
	var me := Game.instance.local_player
	var seabed := Sim.world.seabed
	var sub := Sim.world.sub
	var h := deg_to_rad(r.heading)
	var side := Vector2(cos(h), -sin(h)) * (1.0 if r.seat_of(me.peer_id) % 2 == 0 else -1.0)
	if seabed.floor_depth(r.pos) < 1.2:
		var island := nearest_island(seabed, r.pos)
		if island < 0:
			return
		# Step out on her landward side: whichever side the ground is higher.
		var a := r.pos + side * 1.6
		var b := r.pos - side * 1.6
		var to := a if seabed.floor_depth(a) < seabed.floor_depth(b) else b
		var local := ExteriorWorld.to_3d(to) - ExteriorWorld.to_3d(island_centre(island))
		local.y = maxf(-seabed.floor_depth(to), WADE + 0.1) + 0.3
		_left_at = Sim.world.time
		Game.instance.rq_raft_leave.rpc_id(1, r.id, island)
		me.global_position = ASHORE + local
		me.velocity = Vector3.ZERO
		me.rotation.y = -h
		_last_dry = me.global_position
		_build_ground(island)
		return
	var d := r.pos - sub.pos
	var fwd := Vector2(sin(deg_to_rad(sub.heading)), cos(deg_to_rad(sub.heading)))
	var right := Vector2(fwd.y, -fwd.x)
	var lx := d.dot(right)
	var lz := -d.dot(fwd)
	if Diving.water_y() <= 0.0 and absf(lx) < sub.data.beam * 0.5 + SWIM_OFF and absf(lz) < sub.data.length * 0.5 + SWIM_OFF:
		_left_at = Sim.world.time
		Game.instance.rq_raft_leave.rpc_id(1, r.id, -1)
		var out := 1.0 if lx >= 0.0 else -1.0
		me.global_position = Deck.ORIGIN + Vector3(lx + out * 1.2, Deck.SWIM_EYE - Player.EYE_HEIGHT, lz)
		me.velocity = Vector3.ZERO
		me.rotation.y = -deg_to_rad(r.heading - sub.heading)
		Sfx.play_at(me, "splash", Vector3(0, 1.0, 0), -4.0)
		return
	Game.instance.hud.show_message("Too far out to swim for it. Paddle to a beach, or back alongside the boat.", 4.0)


## The raft within reach of this crewman with a seat free, or null.
func raft_near(player: Player) -> Raft:
	if Sim.world == null or Sim.world.raft_of(player.peer_id) != null:
		return null
	var at := world_pos(player)
	if at == Vector2.INF:
		return null
	for r in Sim.world.rafts:
		if r.free_seat() >= 0 and r.pos.distance_to(at) < REACH + (RaftModel.LENGTH * 0.5 if Deck.is_out(player.global_position) else 0.0):
			return r
	return null


## What E does near a raft (Player asks when nothing else is in front of him).
func prompt_for(player: Player) -> String:
	if raft_near(player) == null:
		return ""
	return "[E] Climb into the raft" if not is_ashore(player.global_position) else "[E] Get in the raft"


func interact(player: Player) -> void:
	var r := raft_near(player)
	if r != null:
		Game.instance.rq_raft_board.rpc_id(1, r.id)
		Sfx.play_at(player, "splash", Vector3(0, 0.5, 0), -10.0, 1.4)


## The island's ground as collision round ASHORE: the very triangles TerrainView draws for it
## (its fine mesh), from the beach and shallows up.
func _build_ground(island: int) -> void:
	if _ground != null:
		_ground.queue_free()
	_ground_island = island
	var seabed := Sim.world.seabed
	var f: Dictionary = seabed.features[island]
	var centre := Vector2(f.x, f.y)
	var reach := float(f.r) * float(f.stretch) * 1.25
	var cells := 110
	var step := reach * 2.0 / cells
	var h := PackedFloat32Array()
	h.resize((cells + 1) * (cells + 1))
	for j in cells + 1:
		for i in cells + 1:
			h[j * (cells + 1) + i] = -seabed.floor_depth(centre + Vector2(-reach + i * step, -reach + j * step))
	var faces := PackedVector3Array()
	for j in cells:
		for i in cells:
			var v: Array[Vector3] = []
			for c: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]:
				v.append(Vector3(-reach + c.x * step, h[c.y * (cells + 1) + c.x], reach - c.y * step))
			if maxf(maxf(v[0].y, v[1].y), maxf(v[2].y, v[3].y)) < -12.0:
				continue
			faces.append_array([v[0], v[2], v[1], v[0], v[3], v[2]])
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	_ground = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	_ground.add_child(cs)
	_ground.position = ASHORE
	add_child(_ground)


## Every raft on the sea, the crew in them and the crew ashore, as the exterior shows them; the
## rocket's roar and the slap of a skip, for whoever is outside to hear.
func _sync_models(delta: float, me: Player) -> void:
	var ext := Game.instance.exterior
	var seen := {}
	var listener := Vector2.INF
	if me != null and Deck.is_outside(me.global_position):
		listener = world_pos(me)
	for r in Sim.world.rafts:
		seen[r.id] = true
		var m: RaftModel = _models.get(r.id)
		if m == null:
			m = RaftModel.new()
			ext.add_child(m)
			_models[r.id] = m
		m.transform = RaftModel.sea_transform(r)
		m.show_state(r)
		# The rocket: a warm roar that rises with her speed, fading with distance.
		var snd: AudioStreamPlayer = _sounds.get(r.id)
		var d := r.pos.distance_to(listener) if listener != Vector2.INF else INF
		var burn := clampf(r.throttle, 0.0, 1.0) if r.rocket else 0.0
		if burn > 0.02 and d < 1500.0:
			if snd == null:
				snd = AudioStreamPlayer.new()
				snd.stream = Sfx.stream("rocket_loop")
				snd.bus = "Effects"
				add_child(snd)
				snd.play()
				_sounds[r.id] = snd
				Sfx.play("rocket_start", -8.0 - 20.0 * log(maxf(d / 4.0, 1.0)) / log(10.0))
			snd.volume_db = -10.0 + 6.0 * burn - 20.0 * log(maxf(d / 4.0, 1.0)) / log(10.0)
			snd.pitch_scale = 0.8 + clampf(absf(r.speed) / Raft.ROCKET_TOP, 0.0, 1.0) * 0.45
		elif snd != null:
			snd.queue_free()
			_sounds.erase(r.id)
		var was: float = _hop.get(r.id, 0.0)
		if was > 0.15 and r.hop <= 0.0 and d < 600.0:
			Sfx.play("splash", -6.0 - 20.0 * log(maxf(d / 4.0, 1.0)) / log(10.0), randf_range(0.6, 0.8))
		_hop[r.id] = r.hop
	for id: int in _models.keys():
		if not seen.has(id):
			_models[id].queue_free()
			_models.erase(id)
			_hop.erase(id)
			if _sounds.has(id):
				_sounds[id].queue_free()
				_sounds.erase(id)
	_sync_figures(delta, me)


func _sync_figures(delta: float, me: Player) -> void:
	var ext := Game.instance.exterior
	var seen := {}
	var ashore: Dictionary = Game.instance.crew.get("ashore", {})
	for p: Player in Game.instance.players():
		if p == me:
			continue
		var r := Sim.world.raft_of(p.peer_id)
		var island: int = ashore.get(p.peer_id, -1)
		var on_land := r == null and is_ashore(p.global_position) and island >= 0 and island < Sim.world.seabed.features.size()
		if r == null and not on_land:
			continue
		seen[p.peer_id] = true
		var f: Dictionary = _figures.get(p.peer_id, {})
		if f.is_empty() or f.look != p.look() or not is_instance_valid(f.node):
			if not f.is_empty() and is_instance_valid(f.node):
				f.node.queue_free()
			f = {"node": Game.instance.deck._figure(p.look(), p.peer_id), "look": p.look(), "stride": 0.0}
			ext.add_child(f.node)
			_figures[p.peer_id] = f
		var n: Node3D = f.node
		var limbs: Dictionary = n.get_meta("limbs")
		if r != null: # sitting on the tube, legs in the raft, paddling or on the tiller
			var seat := r.seat_of(p.peer_id)
			var sit := RaftModel.sea_transform(r) * Transform3D(Basis(Vector3.UP, p.rotation.y * 0.3), RaftModel.SEATS[seat] - Vector3(0, 0.88, 0))
			n.global_transform = sit
			limbs.leg_l.rotation.x = 1.45
			limbs.leg_r.rotation.x = 1.45
			var stroke := sin(Sim.world.time * 4.5 + p.peer_id) * 0.5 if not r.rocket and absf(r.speed) > 0.3 else 0.0
			limbs.arm_l.rotation.x = 0.7 + stroke if seat != 0 or not r.rocket else 0.4
			limbs.arm_r.rotation.x = 0.7 - stroke if seat != 0 or not r.rocket else 1.1 # the driver's hand on the tiller
		else: # walking the beach
			var at := ExteriorWorld.to_3d(island_centre(island)) + (p.global_position - ASHORE)
			var moved := Vector2(at.x - n.position.x, at.z - n.position.z).length()
			n.position = at
			n.rotation = Vector3(0.0, p.rotation.y, 0.0)
			f.stride += moved * 6.0
			var swing := sin(f.stride) * clampf(moved / maxf(delta, 0.001) / 3.0, 0.0, 1.0) * 0.6
			limbs.leg_l.rotation.x = swing
			limbs.leg_r.rotation.x = -swing
			limbs.arm_l.rotation.x = -swing * 0.8
			limbs.arm_r.rotation.x = swing * 0.8
	for id: int in _figures.keys():
		if not seen.has(id):
			if is_instance_valid(_figures[id].node):
				_figures[id].node.queue_free()
			_figures.erase(id)


## Host: empty rafts hauled in alongside her are stowed back in the locker; nobody stays in a
## seat he's left the game from.
func host_tick() -> void:
	var sub := Sim.world.sub
	var here := {}
	for p: Player in Game.instance.players():
		here[p.peer_id] = true
	for r in Sim.world.rafts:
		for i in Raft.SEATS:
			if r.crew[i] != 0 and not here.has(r.crew[i]):
				r.crew[i] = 0
				r.paddles[i] = 0.0
	Sim.world.rafts = Sim.world.rafts.filter(func(r: Raft) -> bool:
		return not (r.is_empty() and r.empty_for > STOW_AFTER and r.pos.distance_to(sub.pos) < STOW_NEAR + sub.data.length * 0.5))
