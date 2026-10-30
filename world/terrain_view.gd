class_name TerrainView
extends Node3D
## The islands and the sea floor around them, built from the Seabed as low-poly, flat-shaded
## meshes: rock and jungle up top, grass, a sand beach, then pale sand and coral on the reef
## and blue-grey slopes into the deep. A few palms stand on each island. Rebuilt whenever the
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
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	return m


## Height (m, + above water) to a hand-painted colour, varied a little per triangle.
func _colour(y: float, rng: RandomNumberGenerator) -> Color:
	var c: Color
	if y > 140.0:
		c = Color("#6E6A5E") # bare rock peaks
	elif y > 45.0:
		c = Color("#3E7D3F") # deep jungle
	elif y > 3.0:
		c = Color("#5FA35A") # grass and scrub
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


## Palms on the low ground behind the beach, each leaning a little its own way.
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
		palm.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))
		var tall := rng.randf_range(12.0, 20.0)
		Build.cyl(palm, 0.5, tall, Vector3(0, tall * 0.5, 0), Color("#8A6A45"))
		for k in 6:
			var leaf := Node3D.new()
			leaf.position.y = tall
			leaf.rotation = Vector3(-0.45, k * TAU / 6.0, 0.0)
			palm.add_child(leaf)
			Build.box(leaf, Vector3(1.6, 0.25, 8.0), Vector3(0, -0.8, -4.0), Color("#3F8A3A"), false)
		add_child(palm)
		placed += 1


## Sim plane (x east, y north) to 3D, as in ExteriorWorld (kept here so this needs no autoloads).
static func _to_3d(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, -p.y)
