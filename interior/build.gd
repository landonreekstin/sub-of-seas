class_name Build
## Helpers for building the boat and ships from primitives: boxes with bevelled edges,
## lathed cylinders with chamfered rims, curved hull panels, in the painted toon material.

## Palette colour -> [detail texture, metres per repeat]. The grey detail maps
## (tools/make_textures.py) multiply the flat colour, so the palette stays the palette.
const DETAIL := {
	"9db59a": ["painted_steel", 1.6], "b5c4b0": ["painted_steel", 1.6], "d8d2c0": ["painted_steel", 1.0],
	"5e6b5c": ["deck_plate", 1.2], "4e5550": ["painted_steel", 1.2], "6e756c": ["brushed", 0.8],
	"c9a04a": ["brushed", 0.5], "8a8f86": ["brushed", 0.8], "3a3f38": ["painted_steel", 1.2],
	"4a5248": ["painted_steel", 1.0], "6b5a44": ["wood", 1.5], "5d6b4e": ["brushed", 1.0],
	"4a4e55": ["ship_plating", 12.0], "8c9096": ["ship_plating", 8.0], "8b7355": ["wood", 6.0],
	"5a5f66": ["ship_plating", 8.0], "c8c4b8": ["ship_plating", 6.0],
}

## Detail map -> [bump, cavity]: how hard its height map bends the light, how dark its
## hollows get (world/toon.gdshader).
const RELIEF := {
	"painted_steel": [3.0, 0.5], "deck_plate": [3.5, 0.6], "brushed": [1.0, 0.2],
	"wood": [2.5, 0.6], "ship_plating": [2.5, 0.4], "grain": [1.2, 0.0], "cloth": [0.7, 0.15],
	"skin": [0.8, 0.0], "hair": [2.0, 0.5], "rock": [2.5, 0.5],
}
## Named surfaces for `mat(color, 0, surface)`: [metres per repeat, painted blotchiness].
const SURFACES := {"cloth": [0.2, 0.6], "skin": [0.15, 0.2], "hair": [0.12, 0.25], "rock": [6.0, 0.8]}
## Every opaque colour without its own map gets a fine painted grain.
const DEFAULT_DETAIL := ["grain", 0.6]

static var _materials := {}
static var _meshes := {}
static var _textures := {}


static func detail_texture(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load("res://assets/textures/%s.png" % name)
	return _textures[name]


## Shinier palette colours (brass, gauge glass): a tighter toon highlight.
const SHINY := {"c9a04a": 0.35, "8a8f86": 0.5, "6e756c": 0.55}
const TOON_SHADER := preload("res://world/toon.gdshader")


## The painted toon material (world/toon.gdshader) for an opaque palette colour; glowing
## and see-through colours keep a plain material.
## `surface` picks a detail map by name ("cloth") instead of by colour.
static func mat(color: Color, emission := 0.0, surface := "") -> Material:
	var key := "%s/%s/%s" % [color.to_html(), emission, surface]
	if not _materials.has(key) and emission == 0.0 and color.a >= 1.0:
		var t := ShaderMaterial.new()
		t.shader = TOON_SHADER
		t.set_shader_parameter("albedo", color)
		t.set_shader_parameter("roughness", SHINY.get(color.to_html(false), 0.75))
		var dt: Array = DETAIL.get(color.to_html(false), DEFAULT_DETAIL)
		var paint := 1.0 if dt[1] < 4.0 else 0.6
		if surface != "":
			dt = [surface, SURFACES[surface][0]]
			paint = SURFACES[surface][1]
		t.set_shader_parameter("detail", detail_texture(dt[0]))
		t.set_shader_parameter("height_map", detail_texture(dt[0] + "_h"))
		t.set_shader_parameter("use_detail", true)
		t.set_shader_parameter("detail_scale", 1.0 / float(dt[1]))
		t.set_shader_parameter("paint_scale", clampf(1.6 / float(dt[1]), 0.15, 1.0))
		t.set_shader_parameter("paint", paint)
		var relief: Array = RELIEF.get(dt[0], [0.0, 0.0])
		t.set_shader_parameter("bump", relief[0])
		t.set_shader_parameter("cavity", relief[1])
		_materials[key] = t
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.75
		var d: Array = DETAIL.get(color.to_html(false), [])
		if not d.is_empty() and emission == 0.0:
			m.albedo_texture = detail_texture(d[0])
			m.uv1_triplanar = true
			m.uv1_scale = Vector3.ONE / float(d[1])
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		# Toon-ish: light wraps softly round the chunky shapes, with a touch of rim light.
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		m.rim_enabled = true
		m.rim = 0.2
		m.rim_tint = 0.6
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
	mi.mesh = bevel_box_mesh(size)
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
	var c := minf(radius * 0.18, length * 0.12)
	var h := length * 0.5
	mi.mesh = lathe_mesh([Vector2(0, -h), Vector2(radius - c, -h), Vector2(radius, -h + c),
			Vector2(radius, h - c), Vector2(radius - c, h), Vector2(0, h)], 20 if radius > 0.04 else 10)
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
	mesh.radial_segments = 20
	mesh.rings = 10
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


## A trigger volume the interaction ray can find but players walk through.
static func area(owner_node: Node3D, size: Vector3, pos: Vector3) -> Area3D:
	var a := Area3D.new()
	a.position = pos
	a.monitoring = false
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	a.add_child(shape)
	owner_node.add_child(a)
	return a


## Simple CPU particles: small glowing quads, for spray, flame and sparks.
static func particles(parent: Node3D, color: Color, amount: int, lifetime: float, dir: Vector3,
		speed: float, spread_deg: float, gravity: Vector3, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = size * 0.5
	mesh.height = size
	mesh.radial_segments = 6
	mesh.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	mesh.material = m
	p.mesh = mesh
	p.amount = amount
	p.lifetime = lifetime
	p.direction = dir
	p.spread = spread_deg
	p.initial_velocity_min = speed * 0.7
	p.initial_velocity_max = speed
	p.gravity = gravity
	var fade := Gradient.new()
	fade.set_color(0, color)
	fade.set_color(1, Color(color, 0.0))
	p.color_ramp = fade
	parent.add_child(p)
	return p


## A Mark 14 torpedo lying along Z, nose towards -Z (+Z when `aft`): olive body with a
## grey warhead, tapered tail with four fins and twin brass screws.
static func torpedo(parent: Node3D, radius: float, length: float, pos: Vector3, aft := false) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	if aft:
		root.rotation.y = PI
	parent.add_child(root)
	var r := radius
	var h := length * 0.5
	var war := h - length * 0.22 # where the warhead joins the body
	# Profile along +Y = towards the nose (turned to -Z below).
	var body := lathe(root, [Vector2(0, -h + 0.25), Vector2(r * 0.32, -h + 0.25), Vector2(r * 0.7, -h + length * 0.08),
			Vector2(r, -h + length * 0.2), Vector2(r, war)], Vector3.ZERO, Color("#5D6B4E"), Vector3.FORWARD, 20)
	body.name = "Body"
	var nose: Array = []
	for i in 7:
		var t := i / 6.0
		nose.append(Vector2(r * sqrt(maxf(1.0 - t * t, 0.0)) if i < 6 else 0.0, war + (h - war) * (1.0 - pow(1.0 - t, 1.6)) * 1.0 if i > 0 else war))
	lathe(root, nose, Vector3.ZERO, Color("#6E756C"), Vector3.FORWARD, 20)
	lathe(root, [Vector2(0, -0.01), Vector2(r * 1.02, -0.01), Vector2(r * 1.02, 0.03), Vector2(0, 0.03)], Vector3(0, 0, -war), Color("#3A3F38"), Vector3.FORWARD, 20)
	# Fins and screws at the tail.
	var tail := h - 0.22
	for k in 4:
		var fin := box(root, Vector3(0.015, r * 1.5, 0.3), Vector3(0, 0, tail - 0.05), Color("#5D6B4E"), false)
		fin.rotation.z = k * PI * 0.5 + PI * 0.25
		fin.position += Vector3(cos(fin.rotation.z + PI * 0.5), sin(fin.rotation.z + PI * 0.5), 0) * r * 0.5
	for k in 2:
		var hub := Vector3(0, 0, h - 0.18 + k * 0.12)
		for b in 4:
			var blade := box(root, Vector3(r * 0.9, 0.05, 0.02), hub, Color("#C9A04A"), false)
			blade.rotation = Vector3(0.0, 0.0, b * PI * 0.5 + k * PI * 0.25)
			blade.rotation.y = 0.35 if k == 0 else -0.35
	return root


## The toon material for vertex-coloured, two-sided terrain: islands and the sea floor,
## with the rock map at `metres` per repeat.
static func terrain_mat(metres := 8.0) -> ShaderMaterial:
	var key := "terrain/%s" % metres
	if not _materials.has(key):
		var sh := Shader.new()
		sh.code = TOON_SHADER.code.replace("render_mode cull_back;", "render_mode cull_disabled;")
		var t := ShaderMaterial.new()
		t.shader = sh
		t.set_shader_parameter("albedo", Color.WHITE)
		t.set_shader_parameter("vertex_color", true)
		t.set_shader_parameter("roughness", 0.95)
		t.set_shader_parameter("detail", detail_texture("rock"))
		t.set_shader_parameter("height_map", detail_texture("rock_h"))
		t.set_shader_parameter("use_detail", true)
		t.set_shader_parameter("detail_scale", 1.0 / metres)
		t.set_shader_parameter("paint_scale", 0.05)
		t.set_shader_parameter("paint", 0.6)
		t.set_shader_parameter("bump", 2.0)
		t.set_shader_parameter("cavity", 0.4)
		_materials[key] = t
	return _materials[key]


# --- Meshes ------------------------------------------------------------------

## Adds triangle a, b, c facing `n` (Godot's front faces wind clockwise), flat-shaded.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	st.set_normal(n)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


## A box of `size` with its edges and corners bevelled, so they catch the light. The bevel
## grows with the box: a hair on a playing card, a hand's width on a ship's bridge.
static func bevel_box_mesh(size: Vector3) -> Mesh:
	var key := "box%s" % size
	if _meshes.has(key):
		return _meshes[key]
	var c := minf(minf(size.x, minf(size.y, size.z)) * 0.12, 0.35)
	var h := size * 0.5
	var inner := h - Vector3(c, c, c)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The corner of octant s, pushed out along axis `ax`.
	var p := func(s: Vector3, ax: int) -> Vector3:
		var v := inner * s
		v[ax] = h[ax] * s[ax]
		return v
	for ax in 3:
		var u := (ax + 1) % 3
		var w := (ax + 2) % 3
		for sa in [-1.0, 1.0]:
			# The face.
			var n := Vector3.ZERO
			n[ax] = sa
			var q: Array[Vector3] = []
			for su in [-1.0, 1.0]:
				for sw in [-1.0, 1.0]:
					var s := Vector3.ZERO
					s[ax] = sa
					s[u] = su
					s[w] = sw
					q.append(p.call(s, ax))
			_tri(st, q[0], q[1], q[3], n)
			_tri(st, q[0], q[3], q[2], n)
			# The edge bevel between this face and the +/- u face, both ends along w.
			for su in [-1.0, 1.0]:
				var e := Vector3.ZERO
				e[ax] = sa
				e[u] = su
				var s0 := e
				s0[w] = -1.0
				var s1 := e
				s1[w] = 1.0
				var a0: Vector3 = p.call(s0, ax)
				var a1: Vector3 = p.call(s1, ax)
				var b0: Vector3 = p.call(s0, u)
				var b1: Vector3 = p.call(s1, u)
				var en := e.normalized()
				if ax < u or (ax == 2 and u == 0):
					_tri(st, a0, a1, b1, en)
					_tri(st, a0, b1, b0, en)
	# The eight corner triangles.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var s := Vector3(sx, sy, sz)
				_tri(st, p.call(s, 0), p.call(s, 1), p.call(s, 2), s.normalized())
	var m := st.commit()
	_meshes[key] = m
	return m


## A surface of revolution round Y from `profile` (x = radius, y = height), bottom to top.
## Smooth round the axis, crisp at each corner of the profile.
static func lathe_mesh(profile: Array, segments := 20) -> Mesh:
	var key := "lathe%s/%d" % [str(profile), segments]
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size() - 1:
		var p0: Vector2 = profile[i]
		var p1: Vector2 = profile[i + 1]
		var d := p1 - p0
		if d.length() < 0.00001:
			continue
		var pn := Vector2(d.y, -d.x).normalized() # outward in the profile plane
		for k in segments:
			var a0 := TAU * k / segments
			var a1 := TAU * (k + 1) / segments
			var r0 := Vector3(cos(a0), 0, sin(a0))
			var r1 := Vector3(cos(a1), 0, sin(a1))
			var v00 := r0 * p0.x + Vector3(0, p0.y, 0)
			var v01 := r1 * p0.x + Vector3(0, p0.y, 0)
			var v10 := r0 * p1.x + Vector3(0, p1.y, 0)
			var v11 := r1 * p1.x + Vector3(0, p1.y, 0)
			var n0 := r0 * pn.x + Vector3(0, pn.y, 0)
			var n1 := r1 * pn.x + Vector3(0, pn.y, 0)
			_quad_smooth(st, v00, v01, v11, v10, n0, n1, n1, n0)
	var m := st.commit()
	_meshes[key] = m
	return m


## A quad a-b-c-d with a normal per corner; turned to face the way the normals point.
static func _quad_smooth(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3) -> void:
	var n := na + nb + nc + nd
	var tris := [[a, b, c, na, nb, nc], [a, c, d, na, nc, nd]]
	for t in tris:
		var v0: Vector3 = t[0]
		var v1: Vector3 = t[1]
		var v2: Vector3 = t[2]
		var m0: Vector3 = t[3]
		var m1: Vector3 = t[4]
		var m2: Vector3 = t[5]
		if (v1 - v0).cross(v2 - v0).length_squared() < 1e-12:
			continue
		if (v1 - v0).cross(v2 - v0).dot(n) > 0.0:
			var tv := v1
			v1 = v2
			v2 = tv
			var tm := m1
			m1 = m2
			m2 = tm
		st.set_normal(m0)
		st.add_vertex(v0)
		st.set_normal(m1)
		st.add_vertex(v1)
		st.set_normal(m2)
		st.add_vertex(v2)


## A lathed shape (see lathe_mesh) placed at `pos`, its axis along `axis`.
static func lathe(parent: Node3D, profile: Array, pos: Vector3, color: Color, axis := Vector3.UP,
		segments := 20) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = lathe_mesh(profile, segments)
	mi.material_override = mat(color)
	mi.position = pos
	if axis.normalized().is_equal_approx(Vector3.DOWN):
		mi.rotation.x = PI
	elif axis != Vector3.UP:
		mi.basis = Basis(Quaternion(Vector3.UP, axis.normalized()))
	parent.add_child(mi)
	return mi


## A curved panel running along Z: the ring sector between angles `a0` and `a1` (radians,
## 0 = +X, counter-clockwise towards +Y) at `radius` round `center` (x, y), `thickness`
## deep outward, from z0 to z1. Hull shoulders, frames, bilge curves.
static func arc(parent: Node3D, center: Vector2, radius: float, a0: float, a1: float,
		thickness: float, z0: float, z1: float, color: Color, segments := 10) -> MeshInstance3D:
	var key := "arc%s/%s/%s/%s/%s/%s/%d" % [center, radius, a0, a1, thickness, z1 - z0, segments]
	if not _meshes.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var hz := (z1 - z0) * 0.5
		var pt := func(a: float, r: float, z: float) -> Vector3:
			return Vector3(center.x + cos(a) * r, center.y + sin(a) * r, z)
		var ro := radius + thickness
		for k in segments:
			var b0 := lerpf(a0, a1, float(k) / segments)
			var b1 := lerpf(a0, a1, float(k + 1) / segments)
			var d0 := Vector3(cos(b0), sin(b0), 0)
			var d1 := Vector3(cos(b1), sin(b1), 0)
			# Inner face (towards the centre), outer face, and the two ends.
			_quad_smooth(st, pt.call(b0, radius, -hz), pt.call(b1, radius, -hz), pt.call(b1, radius, hz), pt.call(b0, radius, hz), -d0, -d1, -d1, -d0)
			_quad_smooth(st, pt.call(b0, ro, -hz), pt.call(b1, ro, -hz), pt.call(b1, ro, hz), pt.call(b0, ro, hz), d0, d1, d1, d0)
			for e in [[-hz, Vector3.FORWARD], [hz, Vector3.BACK]]:
				var z: float = e[0]
				var n: Vector3 = e[1]
				_quad_smooth(st, pt.call(b0, radius, z), pt.call(b1, radius, z), pt.call(b1, ro, z), pt.call(b0, ro, z), n, n, n, n)
		for e in [[a0, -1.0], [a1, 1.0]]:
			var a: float = e[0]
			var n := Vector3(-sin(a), cos(a), 0) * float(e[1])
			_quad_smooth(st, pt.call(a, radius, -hz), pt.call(a, ro, -hz), pt.call(a, ro, hz), pt.call(a, radius, hz), n, n, n, n)
		_meshes[key] = st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[key]
	mi.material_override = mat(color)
	mi.position.z = (z0 + z1) * 0.5
	parent.add_child(mi)
	return mi
