class_name SeaLifeView
extends Node3D
## Life in the water, for the portholes and the periscope. The whales are the sim's (they are
## sonar contacts too); the rest is scenery kept around the boat: schools of bright fish,
## more and brighter over a reef, a shark or two circling, and octopus on a shallow bottom.

const SCHOOLS := 7
const FISH_PER_SCHOOL := 36
const ROAM := 30.0 ## metres around the boat the scenery keeps to
const FISH_COLOURS: Array[Color] = [Color("#FFD93D"), Color("#3EC8FF"), Color("#FF8A3D"), Color("#7CF2C8"), Color("#FF6FB0"), Color("#C9F2FF")]

var _whales := {} ## id -> Node3D
var _schools: Array[Dictionary] = [] ## {mm: MultiMeshInstance3D, centre: Vector3, vel: Vector3, phase}
var _sharks: Array[Node3D] = []
var _octopi: Array[Node3D] = []
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


func sync(delta: float) -> void:
	if Sim.world == null:
		return
	_t += delta
	_sync_whales()
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
