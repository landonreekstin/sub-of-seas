class_name TerrainView
extends Node3D
## The islands and the sea floor around them, built from the Seabed as low-poly, flat-shaded
## meshes in the toon material with a rock texture: rock and jungle up top, grass, a sand
## beach, then pale sand and coral on the reef and blue-grey slopes into the deep. Palms with
## coconuts behind the beach, round-canopied jungle trees on the slopes, boulders. Rebuilt whenever the
## seabed's features change.

const DEEPEST_DRAWN := 260.0 ## floor deeper than this is never seen, so isn't built
const PALMS_PER_ISLAND := 24

var _built_version := -1


func sync(seabed: Seabed) -> void:
	if seabed.version == _built_version:
		return
	_built_version = seabed.version
	for c in get_children():
		c.queue_free()
	var rng := RandomNumberGenerator.new()
	for i in seabed.features.size():
		var f: Dictionary = seabed.features[i]
		rng.seed = hash([f.x, f.y])
		var reach := float(f.r) * float(f.stretch) * (1.25 if f.kind == "island" else 1.7)
		var cells := 110 if f.kind == "island" else 60
		var mesh := _build(seabed, Vector2(f.x, f.y), reach, cells, rng)
		if mesh != null:
			add_child(mesh)
		if f.kind == "island":
			_palms(seabed, f, rng)
			_jungle(seabed, f, rng)
			_boulders(seabed, f, rng)
			_coral(seabed, f, rng)


## One feature's patch of floor: a square grid `reach` metres each way from `centre`.
func _build(seabed: Seabed, centre: Vector2, reach: float, cells: int, rng: RandomNumberGenerator) -> MeshInstance3D:
	var step := reach * 2.0 / cells
	var h := PackedFloat32Array()
	h.resize((cells + 1) * (cells + 1))
	for j in cells + 1:
		for i in cells + 1:
			h[j * (cells + 1) + i] = -seabed.floor_depth(centre + Vector2(-reach + i * step, -reach + j * step))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1) # flat shaded, low-poly
	var any := false
	for j in cells:
		for i in cells:
			var corners := [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			var v: Array[Vector3] = []
			for c: Vector2i in corners:
				var p := centre + Vector2(-reach + c.x * step, -reach + c.y * step)
				v.append(_to_3d(p, h[c.y * (cells + 1) + c.x]))
			for tri: Array in [[0, 2, 1], [0, 3, 2]]:
				var a: Vector3 = v[tri[0]]
				var b: Vector3 = v[tri[1]]
				var c3: Vector3 = v[tri[2]]
				if maxf(a.y, maxf(b.y, c3.y)) < -DEEPEST_DRAWN:
					continue
				any = true
				st.set_color(_colour((a.y + b.y + c3.y) / 3.0, rng))
				st.add_vertex(a)
				st.add_vertex(b)
				st.add_vertex(c3)
	if not any:
		return null
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = Build.terrain_mat()
	return m


## Height (m, + above water) to a hand-painted colour, varied a little per triangle.
func _colour(y: float, rng: RandomNumberGenerator) -> Color:
	var c: Color
	if y > 140.0:
		c = Color("#6E6A5E") # bare rock peaks
	elif y > 110.0:
		c = Color("#6E6A5E").lerp(Color("#3E7D3F"), rng.randf() * 0.6) # rock breaking through
	elif y > 45.0:
		c = [Color("#2F6A33"), Color("#3E7D3F"), Color("#356F37")][rng.randi() % 3] # deep jungle
	elif y > 3.0:
		c = [Color("#4F8E48"), Color("#5A9A4E"), Color("#46803F"), Color("#6A9E50")][rng.randi() % 4] # grass and scrub
	elif y > -0.5:
		c = Color("#EAD9A6") # beach
	elif y > -14.0:
		c = Color("#D9C48F") if rng.randf() > 0.18 else [Color("#E58A7A"), Color("#F0B24F"), Color("#B27AC4")][rng.randi() % 3] # reef: sand and coral
	elif y > -80.0:
		c = Color("#6E9C93").lerp(Color("#3E6D73"), (-y - 14.0) / 66.0)
	else:
		c = Color("#3E6D73").lerp(Color("#22424F"), clampf((-y - 80.0) / 180.0, 0.0, 1.0))
	var shade := rng.randf_range(-0.05, 0.05)
	return Color(c.r + shade, c.g + shade, c.b + shade * 0.5)


const CORAL_PER_ISLAND := 90
## Blaney's Frutiger Aero reef: glossy, cheerful candy colours.
const CORAL_COLOURS: Array[Color] = [Color("#FF5FA2"), Color("#FF9F43"), Color("#3EE6D0"), Color("#9BE564"), Color("#9D6BFF"), Color("#FFD93D"), Color("#5FC8FF")]


## Coral on the reef flat (2–14 m down): round brain coral, branching stags and flat fans,
## glossy and bright, with bubbles rising off the reef here and there.
func _coral(seabed: Seabed, f: Dictionary, rng: RandomNumberGenerator) -> void:
	var placed := 0
	for attempt in 600:
		if placed >= CORAL_PER_ISLAND:
			return
		var p := Vector2(f.x, f.y) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.5, 1.05) * float(f.r) * float(f.stretch)
		var d := seabed.floor_depth(p)
		if d < 1.5 or d > 14.0:
			continue
		var piece := Node3D.new()
		piece.position = _to_3d(p, -d)
		piece.rotation.y = rng.randf() * TAU
		var col := CORAL_COLOURS[rng.randi() % CORAL_COLOURS.size()]
		var s := rng.randf_range(0.8, 2.2)
		match rng.randi() % 3:
			0: # brain coral
				var b := Build.sphere(piece, s, Vector3(0, s * 0.3, 0), col)
				b.scale = Vector3(1.0, 0.6, 1.0)
			1: # staghorn: a few branches
				for k in 5:
					var br := Build.cyl(piece, 0.12 * s, 1.6 * s, Vector3(0, 0.7 * s, 0), col)
					br.rotation = Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-0.6, 0.6))
			_: # sea fan
				Build.box(piece, Vector3(2.2 * s, 2.0 * s, 0.08), Vector3(0, s, 0), col, false)
		for m in piece.find_children("*", "MeshInstance3D", true, false):
			var mat := StandardMaterial3D.new()
			mat.albedo_color = col
			mat.roughness = 0.15 # glossy, the soap-bottle look
			mat.metallic_specular = 0.9
			mat.rim_enabled = true
			mat.rim = 0.4
			(m as MeshInstance3D).material_override = mat
		if rng.randf() < 0.12:
			var bubbles := Build.particles(piece, Color(0.85, 1.0, 1.0, 0.7), 12, 6.0, Vector3.UP, 1.2, 8.0, Vector3(0, 0.4, 0), 0.25)
			bubbles.position.y = s
		add_child(piece)
		placed += 1


## Palms on the low ground behind the beach, each leaning its own way: a curving ringed
## trunk, a crown of drooping fronds, a cluster of coconuts.
func _palms(seabed: Seabed, f: Dictionary, rng: RandomNumberGenerator) -> void:
	var placed := 0
	for attempt in 300:
		if placed >= PALMS_PER_ISLAND:
			return
		var p := Vector2(f.x, f.y) + Vector2.from_angle(rng.randf() * TAU) * rng.randf() * float(f.r) * float(f.stretch) * 0.6
		var y := -seabed.floor_depth(p)
		if y < 2.0 or y > 35.0:
			continue
		var palm := Node3D.new()
		palm.position = _to_3d(p, y - 0.5)
		palm.rotation.y = rng.randf() * TAU
		var tall := rng.randf_range(12.0, 20.0)
		var lean := rng.randf_range(0.15, 0.45)
		# The trunk in five segments, each bending a little more, narrowing to the top.
		var top := Node3D.new()
		palm.add_child(top)
		var seg := tall / 5.0
		for k in 5:
			var r := lerpf(0.6, 0.35, k / 5.0)
			Build.lathe(top, [Vector2(0, 0), Vector2(r, 0), Vector2(r * 1.08, seg * 0.15), Vector2(r * 0.92, seg),
					Vector2(0, seg)], Vector3.ZERO, Color("#8A6A45"), Vector3.UP, 10)
			var next := Node3D.new()
			next.position.y = seg
			next.rotation.x = lean * 0.22 * (k + 1) / 3.0
			top.add_child(next)
			top = next
		for k in 3:
			Build.sphere(top, 0.42, Vector3(cos(k * 2.1) * 0.45, -0.35, sin(k * 2.1) * 0.45), Color("#6B4A2A"))
		for k in 8:
			var frond := Node3D.new()
			frond.rotation = Vector3(-0.25 - rng.randf() * 0.2, k * TAU / 8.0 + rng.randf() * 0.3, 0.0)
			top.add_child(frond)
			# Two pieces: out from the crown, then drooping down at the tip.
			Build.box(frond, Vector3(1.8, 0.15, 4.2), Vector3(0, 0, -2.1), Color("#3F8A3A"), false)
			var tip := Node3D.new()
			tip.position.z = -4.0
			tip.rotation.x = 0.6
			frond.add_child(tip)
			Build.box(tip, Vector3(1.3, 0.12, 3.4), Vector3(0, 0, -1.7), Color("#4E9C42"), false)
		add_child(palm)
		placed += 1


const TREES_PER_ISLAND := 450
const CANOPY_COLOURS: Array[Color] = [Color("#2F6E35"), Color("#3E7D3F"), Color("#4C8E3E"), Color("#2A5E33")]


## Jungle on the slopes: round, lumpy canopy trees, darker greens than the scrub, thick
## enough to read as forest from the periscope. Drawn as two MultiMeshes (trunks, canopy).
func _jungle(seabed: Seabed, f: Dictionary, rng: RandomNumberGenerator) -> void:
	var trunks: Array[Transform3D] = []
	var blobs: Array[Transform3D] = []
	var colours: Array[Color] = []
	for attempt in TREES_PER_ISLAND * 4:
		if trunks.size() >= TREES_PER_ISLAND:
			break
		var p := Vector2(f.x, f.y) + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * float(f.r) * float(f.stretch) * 0.85
		var y := -seabed.floor_depth(p)
		if y < 4.0 or y > 130.0:
			continue
		var base := _to_3d(p, y - 1.0)
		var s := rng.randf_range(7.0, 13.0)
		trunks.append(Transform3D(Basis.from_scale(Vector3(s * 0.12, s * 1.2, s * 0.12)), base + Vector3(0, s * 0.6, 0)))
		var col := CANOPY_COLOURS[rng.randi() % CANOPY_COLOURS.size()]
		for k in 3:
			var off := Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.0, 0.4), rng.randf_range(-0.5, 0.5)) * s
			var r := s * rng.randf_range(0.55, 0.8)
			blobs.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(r, r * 0.8, r)), base + Vector3(0, s * 1.35, 0) + off))
			colours.append(col.lerp(Color("#6FAE4A"), k * 0.12))
	if trunks.is_empty():
		return
	var trunk_mesh := Build.lathe_mesh([Vector2(0, -0.5), Vector2(1.0, -0.5), Vector2(0.7, 0.5), Vector2(0, 0.5)], 8)
	add_child(_multi(trunk_mesh, trunks, [], Build.mat(Color("#5A4632"))))
	var blob := SphereMesh.new()
	blob.radius = 1.0
	blob.height = 2.0
	blob.radial_segments = 10
	blob.rings = 6
	var leaf := (Build.mat(Color.WHITE) as ShaderMaterial).duplicate() as ShaderMaterial
	leaf.set_shader_parameter("vertex_color", true)
	leaf.set_shader_parameter("paint_scale", 0.3)
	add_child(_multi(blob, blobs, colours, leaf))


func _multi(mesh: Mesh, xforms: Array[Transform3D], colours: Array[Color], material: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colours.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colours[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = material
	return mi


## Grey boulders on the beaches and the rocky slopes, and a few awash at the waterline.
func _boulders(seabed: Seabed, f: Dictionary, rng: RandomNumberGenerator) -> void:
	var placed := 0
	for attempt in 300:
		if placed >= 30:
			return
		var p := Vector2(f.x, f.y) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.4, 1.0) * float(f.r) * float(f.stretch)
		var y := -seabed.floor_depth(p)
		if y < -3.0 or y > 160.0:
			continue
		var s := rng.randf_range(1.5, 5.0)
		var b := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 1.0
		m.height = 2.0
		m.radial_segments = 7
		m.rings = 4
		b.mesh = m
		b.material_override = Build.mat(Color("#7A766A"), 0.0, "rock")
		b.position = _to_3d(p, y + s * 0.2)
		b.scale = Vector3(s * rng.randf_range(0.8, 1.3), s * rng.randf_range(0.5, 0.8), s * rng.randf_range(0.8, 1.3))
		b.rotation = Vector3(rng.randf() * 0.4, rng.randf() * TAU, rng.randf() * 0.4)
		add_child(b)
		placed += 1


## Sim plane (x east, y north) to 3D, as in ExteriorWorld (kept here so this needs no autoloads).
static func _to_3d(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, -p.y)
