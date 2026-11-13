class_name SeaLifeView
extends Node3D
## Life in the water, for the portholes and the periscope. The whales are the sim's (they are
## sonar contacts too); the rest is scenery kept around the boat: schools of bright fish,
## more and brighter over a reef, a shark or two circling, and octopus on a shallow bottom.
## (Blaney: "make the ocean feel more alive") Marine snow drifting down everywhere, catching
## the floodlights; glowing plankton that sparkles in the dark deep down; jellyfish glowing
## as they drift; manta rays and turtles gliding by over shallow water.

const SCHOOLS := 7
const FISH_PER_SCHOOL := 36
const ROAM := 30.0 ## metres around the boat the scenery keeps to
const FISH_COLOURS: Array[Color] = [Color("#FFD93D"), Color("#3EC8FF"), Color("#FF8A3D"), Color("#7CF2C8"), Color("#FF6FB0"), Color("#C9F2FF")]

var _whales := {} ## id -> Node3D
var _monsters := {} ## id -> Node3D
var _schools: Array[Dictionary] = [] ## {mm: MultiMeshInstance3D, centre: Vector3, vel: Vector3, phase}
var _sharks: Array[Node3D] = []
var _octopi: Array[Node3D] = []
var _jellies: Array[Node3D] = []
var _mantas: Array[Node3D] = []
var _turtles: Array[Node3D] = []
var _snow: GPUParticles3D
var _plankton: GPUParticles3D
var _rng := RandomNumberGenerator.new()
var _t := 0.0


func _ready() -> void:
	_rng.randomize()
	var fish := Creatures.fish_mesh()
	for i in SCHOOLS:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = fish
		mm.instance_count = FISH_PER_SCHOOL
		var c := FISH_COLOURS[i % FISH_COLOURS.size()]
		for k in FISH_PER_SCHOOL:
			mm.set_instance_color(k, c.lerp(Color.WHITE, _rng.randf() * 0.25))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = Creatures.creature_mat()
		add_child(mi)
		_schools.append({"mm": mm, "centre": Vector3.INF, "vel": Vector3.ZERO, "phase": _rng.randf() * TAU, "size": _rng.randf_range(3.0, 6.0)})
	for i in 2:
		var s := Creatures.shark()
		s.visible = false
		add_child(s)
		_sharks.append(s)
	for i in 2:
		var o := _octopus()
		o.visible = false
		add_child(o)
		_octopi.append(o)
	for i in JELLIES:
		var j := Creatures.jellyfish([Color("#7FE8FF"), Color("#C49BFF"), Color("#FF9BD8")][i % 3])
		j.scale = Vector3.ONE * _rng.randf_range(0.6, 1.6)
		j.visible = false
		add_child(j)
		_jellies.append(j)
	for i in 2:
		var m := Creatures.manta()
		m.visible = false
		add_child(m)
		_mantas.append(m)
		var t := Creatures.turtle()
		t.visible = false
		add_child(t)
		_turtles.append(t)
	# Marine snow: lit (it glints in the floodlights, unseen in the dark beyond); plankton glows.
	_snow = _drift(1400, 0.05, Color(0.85, 0.9, 0.9), false, 22.0)
	_plankton = _drift(500, 0.07, Color(0.45, 1.0, 0.95), true, 8.0)


const JELLIES := 6
const DRIFT_BOX := Vector3(70.0, 36.0, 70.0) ## m round the boat the specks fill


## Specks drifting slowly down in a box round the boat, left behind in the water as she moves.
func _drift(amount: int, size: float, c: Color, glow: bool, life: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.local_coords = false
	p.visibility_aabb = AABB(-DRIFT_BOX, DRIFT_BOX * 2.0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = DRIFT_BOX * 0.5
	pm.direction = Vector3.DOWN
	pm.spread = 40.0
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.12
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = glow # plankton swirls a little
	pm.turbulence_noise_strength = 0.3
	pm.scale_min = 0.5
	pm.scale_max = 1.5
	if glow: # each one twinkles up and down over its life
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 0.0))
		curve.add_point(Vector2(0.3, 1.0))
		curve.add_point(Vector2(0.5, 0.2))
		curve.add_point(Vector2(0.75, 1.0))
		curve.add_point(Vector2(1.0, 0.0))
		var tex := CurveTexture.new()
		tex.curve = curve
		pm.scale_curve = tex
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_color = c
	if glow:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = m
	p.draw_pass_1 = q
	add_child(p)
	return p


func sync(delta: float) -> void:
	if Sim.world == null:
		return
	_t += delta
	_sync_whales()
	_sync_monsters()
	var sub := Sim.world.sub
	var here := ExteriorWorld.to_3d(sub.pos, -maxf(sub.depth, 3.0))
	var floor_at := Sim.world.seabed.floor_depth(sub.pos)
	var reef := clampf(1.0 - floor_at / 60.0, 0.0, 1.0) # shallow water teems
	var rad := deg_to_rad(sub.heading)
	var fwd := Vector3(sin(rad), 0.0, -cos(rad))
	for i in _schools.size():
		_school(_schools[i], here, fwd, floor_at, delta, i < 4 or reef > 0.2)
	_swim_sharks(here, delta)
	_place_octopi(sub.pos, floor_at)
	_snow.position = here
	_snow.emitting = sub.depth > 2.0
	_snow.visible = _snow.emitting
	var dark := sub.depth > 45.0 or Sim.world.conditions.night
	_plankton.position = here
	_plankton.emitting = dark and sub.depth > 2.0
	_plankton.visible = _plankton.emitting
	_drift_jellies(here, floor_at, delta)
	_glide(here, floor_at, reef)


# --- Whales ------------------------------------------------------------------

func _sync_whales() -> void:
	var seen := {}
	for wh in Sim.world.whales:
		seen[wh.id] = true
		var node: Node3D = _whales.get(wh.id)
		if node == null:
			node = Creatures.whale()
			add_child(node)
			_whales[wh.id] = node
		node.position = ExteriorWorld.to_3d(wh.pos, -wh.depth - 1.0)
		node.rotation = Vector3(0.0, -deg_to_rad(wh.heading), 0.0)
		var flukes: Node3D = node.get_node("Flukes")
		flukes.rotation.x = sin(_t * 0.9 + wh.id) * 0.35
		node.rotation.x = sin(_t * 0.9 + wh.id - 0.8) * 0.04
		var spout: CPUParticles3D = node.get_node("Spout")
		spout.emitting = wh.depth < 1.5 and fmod(_t + wh.id * 3.0, 9.0) < 1.2
	for id: int in _whales.keys():
		if not seen.has(id):
			_whales[id].queue_free()
			_whales.erase(id)


# --- Things from the depths --------------------------------------------------

func _sync_monsters() -> void:
	var seen := {}
	for m in Sim.world.monsters:
		seen[m.id] = true
		var node: Node3D = _monsters.get(m.id)
		if node == null:
			node = Creatures.monster(m.kind, m.length())
			add_child(node)
			_monsters[m.id] = node
		node.position = ExteriorWorld.to_3d(m.pos, -m.depth)
		var swim := _t * (0.6 + m.speed * 0.08) + m.id
		node.rotation = Vector3(0.0, -deg_to_rad(m.heading), PI * 0.8 if m.is_dead() else 0.0)
		match m.kind:
			"squid": # the arms trail and curl, the tentacles reach
				var arms: Node3D = node.get_node("Arms")
				for k in arms.get_child_count():
					var j: Node3D = arms.get_child(k).get_child(0)
					var depth_in := 0
					while j != null:
						j.rotation.x = sin(swim * 1.3 + k + depth_in * 0.7) * 0.12
						j.rotation.y = cos(swim + k * 1.7 + depth_in * 0.5) * 0.1
						depth_in += 1
						j = j.get_child(1) as Node3D if j.get_child_count() > 1 else null
			"serpent": # a wave runs down its body
				var j: Node3D = node.get_node("Seg").get_child(0)
				var i := 0
				while j != null:
					j.rotation.y = sin(swim * 1.6 - i * 0.55) * 0.22
					i += 1
					j = j.get_child(1) as Node3D if j.get_child_count() > 1 else null
			"angler": # the lure bobs in front of the mouth
				(node.get_node("Lure") as Node3D).rotation.z = sin(swim * 0.8) * 0.15
			_:
				(node.get_node("Tail") as Node3D).rotation.y = sin(swim * 1.5) * 0.35
	for id: int in _monsters.keys():
		if not seen.has(id):
			_monsters[id].queue_free()
			_monsters.erase(id)


# --- Fish ----------------------------------------------------------------------

## A school milling around a centre that wanders, kept near the boat (and off the bottom).
func _school(s: Dictionary, here: Vector3, fwd: Vector3, floor_at: float, delta: float, show: bool) -> void:
	var mm: MultiMesh = s.mm
	mm.visible_instance_count = FISH_PER_SCHOOL if show else 0
	if not show:
		return
	var centre: Vector3 = s.centre
	if centre == Vector3.INF or centre.distance_to(here) > ROAM * 1.6:
		# Off one beam or the other, where the portholes look, and a little ahead.
		var beam := fwd.cross(Vector3.UP) * (1.0 if _rng.randf() < 0.5 else -1.0)
		centre = here + beam * _rng.randf_range(3.0, 14.0) + fwd * _rng.randf_range(-6.0, ROAM) + Vector3(0, _rng.randf_range(-4.0, 4.0), 0)
		s.vel = Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized() * _rng.randf_range(0.6, 1.4)
	var vel: Vector3 = s.vel
	vel = vel.rotated(Vector3.UP, sin(_t * 0.2 + s.phase) * 0.3 * delta)
	centre += vel * delta
	centre.y = clampf(centre.y, -floor_at + 2.0, -1.5)
	s.centre = centre
	s.vel = vel
	var size: float = s.size
	for k in FISH_PER_SCHOOL:
		var a := _t * (0.6 + 0.02 * k) + k * 2.399 + float(s.phase)
		var off := Vector3(cos(a) * size, sin(a * 1.7 + k) * size * 0.35, sin(a) * size) * (0.5 + 0.5 * fmod(k * 0.618, 1.0))
		var heading := Vector3(-sin(a), 0.0, cos(a)) + vel * 0.5 # round the ring, and with the school
		var t := Transform3D(Basis.looking_at(heading.normalized(), Vector3.UP), centre + off)
		mm.set_instance_transform(k, t.rotated_local(Vector3.UP, sin(_t * 9.0 + k) * 0.15))


# --- Sharks ------------------------------------------------------------------

## Now and then a shark or two circles the boat for a while.
func _swim_sharks(here: Vector3, _delta: float) -> void:
	for i in _sharks.size():
		var s := _sharks[i]
		var cycle := fmod(_t + i * 70.0, 180.0)
		s.visible = cycle < 75.0
		if not s.visible:
			continue
		var r := 16.0 + i * 9.0
		var a := _t * (0.18 + i * 0.05) * (1.0 if i == 0 else -1.0) + i * 2.0
		s.position = here + Vector3(cos(a) * r, -2.0 + i * 4.0 + sin(_t * 0.3) * 1.5, sin(a) * r)
		var along := Vector3(-sin(a), 0.0, cos(a)) * (1.0 if i == 0 else -1.0)
		s.basis = Basis.looking_at(along, Vector3.UP)
		(s.get_node("Tail") as Node3D).rotation.y = sin(_t * 3.0 + i) * 0.35


# --- Jellyfish, rays, turtles ----------------------------------------------------

## Jellyfish drift round the boat, pulsing; more of them show the deeper she is.
func _drift_jellies(here: Vector3, floor_at: float, _delta: float) -> void:
	var sub := Sim.world.sub
	var show := 2 + int(clampf(sub.depth / 40.0, 0.0, float(JELLIES - 2)))
	for i in _jellies.size():
		var j := _jellies[i]
		j.visible = sub.depth > 2.0 and i < show
		if not j.visible:
			continue
		var at: Vector3 = j.get_meta("at", Vector3.INF)
		if at == Vector3.INF or at.distance_to(here) > ROAM * 1.5: # a new one drifts in ahead of her
			var rad := deg_to_rad(sub.heading)
			var fwd := Vector3(sin(rad), 0.0, -cos(rad))
			at = here + fwd * _rng.randf_range(10.0, ROAM) + fwd.cross(Vector3.UP) * _rng.randf_range(-15.0, 15.0) + Vector3(0, _rng.randf_range(-8.0, 6.0), 0)
			at.y = clampf(at.y, -floor_at + 3.0, -2.0)
		var beat := sin(_t * 1.6 + i * 1.3)
		at.y += maxf(beat, 0.0) * 0.004 # each pulse lifts it a little
		j.set_meta("at", at)
		j.position = at + Vector3(sin(_t * 0.2 + i), 0.0, cos(_t * 0.17 + i)) * 1.5
		var bell := j.get_node("Bell") as Node3D
		bell.scale = Vector3(1.0 - beat * 0.12, 1.0 + beat * 0.15, 1.0 - beat * 0.12)


## Over shallow water (the light reaches, under 80 m), a manta ray or two and a turtle glide past.
func _glide(here: Vector3, floor_at: float, reef: float) -> void:
	var shallow := floor_at < 80.0 and Sim.world.sub.depth < 60.0
	for i in 2:
		for kind in 2:
			var c: Node3D = _mantas[i] if kind == 0 else _turtles[i]
			var cycle := fmod(_t + i * 55.0 + kind * 30.0, 140.0)
			c.visible = shallow and cycle < (90.0 if reef > 0.2 or kind == 0 else 50.0)
			if not c.visible:
				continue
			var r := (22.0 if kind == 0 else 12.0) + i * 7.0
			var dir := 1.0 if (i + kind) % 2 == 0 else -1.0
			var a := _t * (0.07 if kind == 0 else 0.1) * dir + i * 2.5 + kind
			var y := clampf(-floor_at + 4.0 + i * 3.0, here.y - 10.0, -3.0)
			c.position = Vector3(here.x + cos(a) * r, y + sin(_t * 0.25 + i) * 1.2, here.z + sin(a) * r)
			c.basis = Basis.looking_at(Vector3(-sin(a), 0.0, cos(a)) * dir, Vector3.UP)
			if kind == 0:
				var flap := sin(_t * 1.1 + i) * 0.35
				(c.get_node("WingL") as Node3D).rotation.z = -flap
				(c.get_node("WingR") as Node3D).rotation.z = flap
			else:
				for k in 4:
					(c.get_node("Flip%d" % k) as Node3D).rotation.y = sin(_t * 1.4 + k * 0.3) * (0.5 if k < 2 else 0.2) * (1.0 if k % 2 == 0 else -1.0)


# --- Octopus -------------------------------------------------------------------

func _octopus() -> Node3D:
	var o := Node3D.new()
	var col := Color("#E2703A")
	var head := Build.sphere(o, 0.45, Vector3(0, 0.6, 0.15), col)
	head.scale = Vector3(1.0, 1.25, 1.1)
	for side in [-1.0, 1.0]:
		Build.sphere(o, 0.08, Vector3(side * 0.2, 0.55, -0.25), Color("#1A1A1A"))
	for k in 8:
		var arm := Node3D.new()
		arm.name = "Arm%d" % k
		arm.position = Vector3(0, 0.3, 0)
		arm.rotation.y = k * TAU / 8.0
		o.add_child(arm)
		var seg := arm
		for j in 3:
			var piece := Node3D.new()
			piece.position = Vector3(0, 0, 0.0 if j == 0 else 0.32)
			seg.add_child(piece)
			Build.cyl(piece, 0.07 - j * 0.015, 0.34, Vector3(0, 0, 0.16), col.darkened(j * 0.1), Vector3.BACK)
			seg = piece
	return o


## On a bottom the light reaches (under 60 m), an octopus or two near the boat.
func _place_octopi(sub_pos: Vector2, floor_at: float) -> void:
	for i in _octopi.size():
		var o := _octopi[i]
		o.visible = floor_at < 60.0
		if not o.visible:
			continue
		var spot := sub_pos + Vector2.from_angle(i * 2.6 + 0.7) * (10.0 + i * 8.0)
		o.position = ExteriorWorld.to_3d(spot, -Sim.world.seabed.floor_depth(spot) + 0.1)
		for k in 8:
			var arm: Node3D = o.get_node("Arm%d" % k)
			arm.rotation.x = 0.9 + sin(_t * 1.3 + k) * 0.25
			for piece in arm.get_children():
				if piece is Node3D and piece.get_child_count() > 0:
					(piece as Node3D).rotation.x = sin(_t * 1.6 + k * 0.7) * 0.3
