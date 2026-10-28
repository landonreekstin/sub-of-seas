class_name Build
## Helpers for building greybox geometry from primitives (Peak-like flat colours).

static var _materials := {}


static func mat(color: Color, emission := 0.0) -> StandardMaterial3D:
	var key := "%s/%s" % [color.to_html(), emission]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.75
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if emission > 0.0:
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = emission
		_materials[key] = m
	return _materials[key]


static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, collide := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat(color)
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		shape.shape = bs
		body.add_child(shape)
		mi.add_child(body)
	return mi


## A cylinder. `axis` is the direction it runs along (Y default).
static func cyl(parent: Node3D, radius: float, length: float, pos: Vector3, color: Color,
		axis := Vector3.UP, collide := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 12
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = mat(color)
	mi.position = pos
	if axis == Vector3.FORWARD or axis == Vector3.BACK:
		mi.rotation.x = PI / 2.0
	elif axis == Vector3.RIGHT or axis == Vector3.LEFT:
		mi.rotation.z = PI / 2.0
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = radius
		cs.height = length
		shape.shape = cs
		body.add_child(shape)
		mi.add_child(body)
	return mi


static func sphere(parent: Node3D, radius: float, pos: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mi.mesh = mesh
	mi.material_override = mat(color, emission)
	mi.position = pos
	parent.add_child(mi)
	return mi


## A valve wheel / helm wheel facing along `facing`.
static func wheel(parent: Node3D, radius: float, pos: Vector3, color: Color, facing := Vector3.BACK) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.basis = Basis.looking_at(facing, Vector3.UP if absf(facing.y) < 0.9 else Vector3.FORWARD)
	parent.add_child(root)
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.82
	torus.outer_radius = radius
	torus.rings = 16
	torus.ring_segments = 6
	mi.mesh = torus
	mi.material_override = mat(color)
	mi.rotation.x = PI / 2.0
	root.add_child(mi)
	for i in 3:
		var spoke := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(radius * 1.8, radius * 0.1, radius * 0.1)
		spoke.mesh = bm
		spoke.material_override = mat(color)
		spoke.rotation.z = i * PI / 3.0
		root.add_child(spoke)
	return root


static func label(parent: Node3D, text: String, pos: Vector3, size := 48, color := Color("#F2E8CF")) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.002
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	parent.add_child(l)
	return l


## A static collider used only so the interaction ray can find `owner_node`.
static func hitbox(owner_node: Node3D, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	owner_node.add_child(body)
	return body
