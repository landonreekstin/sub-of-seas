class_name Creatures
## The sea life's bodies (SeaLifeView swims them): smooth streamlined meshes with a dark back
## and pale belly in vertex colours, flat fins, in the toon material. No autoloads, so the
## gallery tool can show them.

## A humpback: a long smooth body, slate above and pale below with throat grooves, knobbly
## head, long white flippers, broad flukes. Bow to -Z.
static func whale() -> Node3D:
	var w := Node3D.new()
	var L := Whale.LENGTH
	var st := _begin()
	_spindle(st, L * 0.85, [[0.0, 0.0, 0.0], [0.04, 0.9, 0.8], [0.15, 1.6, 1.5], [0.35, 2.0, 1.75], [0.55, 1.7, 1.5],
			[0.75, 1.0, 1.0], [0.92, 0.45, 0.5], [1.0, 0.25, 0.3]], Vector3(0, 0, -L * 0.06), Color("#34495A"), Color("#D3DADD"), 0.0, true)
	# A dorsal hump two-thirds back.
	_fin(st, [Vector3(0, 1.3, L * 0.15), Vector3(0, 2.1, L * 0.21), Vector3(0, 1.1, L * 0.26)], Color("#2E4050"))
	for side in [-1.0, 1.0]: # the long flippers, white below
		var root := Vector3(side * 1.6, -0.7, -L * 0.22)
		var tip := root + Vector3(side * 4.6, -1.6, 1.6)
		_fin(st, [root + Vector3(0, 0, -0.6), tip, root + Vector3(0, 0, 0.7)], Color("#D8DEE2"))
	var body := MeshInstance3D.new()
	body.mesh = _commit(st)
	body.material_override = creature_mat()
	w.add_child(body)
	for k in 9: # knobs on the head
		Build.sphere(w, 0.13, Vector3(sin(k * 1.7) * 0.4, 0.75 + k * 0.06 - absf(sin(k * 1.7)) * 0.15, -L * 0.43 + k * 0.4), Color("#2B3B48"))
	for side in [-1.0, 1.0]:
		Build.sphere(w, 0.1, Vector3(side * 1.5, -0.1, -L * 0.3), Color("#111418"))
	var flukes := Node3D.new()
	flukes.name = "Flukes"
	flukes.position = Vector3(0, 0.0, L * 0.34)
	w.add_child(flukes)
	var fs := _begin()
	for side in [-1.0, 1.0]:
		_fin(fs, [Vector3(0, 0, 0.2), Vector3(side * 2.8, 0, 2.6), Vector3(side * 1.9, 0, 3.2), Vector3(0, 0, 2.4)], Color("#2B3B48"))
	var fm := MeshInstance3D.new()
	fm.mesh = _commit(fs)
	fm.material_override = creature_mat()
	flukes.add_child(fm)
	var spout := Build.particles(w, Color(1, 1, 1, 0.8), 40, 1.6, Vector3.UP, 9.0, 12.0, Vector3(0, -4, 0), 0.8)
	spout.name = "Spout"
	spout.position = Vector3(0, 1.6, -3.5)
	spout.emitting = false
	return w


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _commit(st: SurfaceTool) -> Mesh:
	st.index()
	st.generate_normals()
	return st.commit()


## The toon material, coloured by the creatures' vertex colours (and a school's own colour).
static func creature_mat() -> ShaderMaterial:
	var m := (Build.mat(Color.WHITE) as ShaderMaterial).duplicate() as ShaderMaterial
	m.set_shader_parameter("vertex_color", true)
	m.set_shader_parameter("paint", 0.3)
	m.set_shader_parameter("roughness", 0.4)
	return m


## A smooth streamlined body along Z (nose at -Z): `stations` are [t 0..1 nose to tail,
## half-width, half-height]; `back` colour over the top, `belly` under it, the line between at
## `line` (-1 bottom .. 1 top). `grooves` stripes the belly (a rorqual's throat).
static func _spindle(st: SurfaceTool, length: float, stations: Array, offset: Vector3, back: Color, belly: Color,
		line := 0.0, grooves := false, segs := 14) -> void:
	var ring := func(i: int, k: int) -> Vector3:
		var stn: Array = stations[i]
		var a := TAU * k / segs
		return offset + Vector3(cos(a) * stn[1], sin(a) * stn[2], -length * 0.5 + float(stn[0]) * length)
	var colour := func(i: int, k: int) -> Color:
		var sy := sin(TAU * k / segs)
		var c := back.lerp(belly, smoothstep(line + 0.25, line - 0.25, sy))
		if grooves and sy < -0.3 and float(stations[i][0]) < 0.45 and k % 2 == 0:
			c = c.darkened(0.18)
		return c
	for i in stations.size() - 1:
		for k in segs:
			var q := [ring.call(i, k), ring.call(i + 1, k), ring.call(i + 1, k + 1), ring.call(i, k + 1)]
			var cs := [colour.call(i, k), colour.call(i + 1, k), colour.call(i + 1, k + 1), colour.call(i, k + 1)]
			var mid: Vector3 = (q[0] + q[1] + q[2] + q[3]) * 0.25
			var out := Vector3(mid.x - offset.x, mid.y - offset.y, 0.0)
			for t in [[0, 1, 2], [0, 2, 3]]:
				_ctri(st, [q[t[0]], q[t[1]], q[t[2]]], [cs[t[0]], cs[t[1]], cs[t[2]]], out)


## A flat fin (a fan of the points), seen from both sides.
static func _fin(st: SurfaceTool, pts: Array, c: Color) -> void:
	for i in range(1, pts.size() - 1):
		var tri := [pts[0], pts[i], pts[i + 1]]
		var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0])
		_ctri(st, tri, [c, c, c], n)
		_ctri(st, tri, [c, c, c], -n)


static func _ctri(st: SurfaceTool, v: Array, c: Array, out: Vector3) -> void:
	var n: Vector3 = (v[1] - v[0]).cross(v[2] - v[0])
	if n.length_squared() < 1e-10:
		return
	var order := [0, 2, 1] if n.dot(out) > 0.0 else [0, 1, 2] # front faces wind clockwise
	for o in order:
		st.set_color(c[o])
		st.add_vertex(v[o])


## A little fish, nose to -Z: a deep, flat-sided body, dark back and pale belly (the
## school's colour tints it), a dorsal fin, a forked tail and a dark eye.
static func fish_mesh() -> Mesh:
	var st := _begin()
	_spindle(st, 0.75, [[0.0, 0.0, 0.0], [0.08, 0.05, 0.08], [0.3, 0.09, 0.2], [0.55, 0.07, 0.17], [0.85, 0.03, 0.06], [1.0, 0.015, 0.03]],
			Vector3.ZERO, Color(0.8, 0.8, 0.85), Color.WHITE, 0.1, false, 10)
	var g := Color(0.92, 0.92, 0.95)
	_fin(st, [Vector3(0, 0.17, -0.1), Vector3(0, 0.3, 0.05), Vector3(0, 0.12, 0.2)], g) # dorsal
	_fin(st, [Vector3(0, 0.0, 0.33), Vector3(0, 0.2, 0.5), Vector3(0, 0.0, 0.42), Vector3(0, -0.2, 0.5)], g) # forked tail
	for side in [-1.0, 1.0]:
		var e := Vector3(side * 0.075, 0.06, -0.24)
		_fin(st, [e + Vector3(0, 0.03, 0), e + Vector3(side * 0.005, 0, 0.03), e + Vector3(0, -0.03, 0), e + Vector3(side * 0.005, 0, -0.03)], Color(0.05, 0.05, 0.08))
	return _commit(st)


## A grey shark, white below: a torpedo body, tall dorsal, swept pectorals, and a tail with
## a big upper lobe (its own node, "Tail", so it sweeps). Nose to -Z.
static func shark() -> Node3D:
	var s := Node3D.new()
	var st := _begin()
	_spindle(st, 3.6, [[0.0, 0.0, 0.0], [0.05, 0.2, 0.16], [0.2, 0.42, 0.45], [0.45, 0.45, 0.5], [0.7, 0.28, 0.32],
			[0.92, 0.1, 0.14], [1.0, 0.06, 0.08]], Vector3.ZERO, Color("#7E8B95"), Color("#E3E8EA"), -0.2)
	var g := Color("#6E7B85")
	_fin(st, [Vector3(0, 0.42, -0.5), Vector3(0, 1.15, 0.1), Vector3(0, 0.95, 0.15), Vector3(0, 0.4, 0.25)], g) # dorsal
	_fin(st, [Vector3(0, 0.2, 1.05), Vector3(0, 0.45, 1.3), Vector3(0, 0.16, 1.3)], g) # second dorsal
	for side in [-1.0, 1.0]:
		_fin(st, [Vector3(side * 0.35, -0.2, -0.55), Vector3(side * 1.2, -0.6, 0.15), Vector3(side * 0.35, -0.25, 0.0)], g)
		_fin(st, [Vector3(side * 0.2, -0.2, -1.15), Vector3(side * 0.24, -0.2, -1.05), Vector3(side * 0.2, -0.23, -0.95)], Color("#2A2E33")) # gills
	var body := MeshInstance3D.new()
	body.mesh = _commit(st)
	body.material_override = creature_mat()
	s.add_child(body)
	for side in [-1.0, 1.0]:
		Build.sphere(s, 0.04, Vector3(side * 0.2, 0.08, -1.4), Color("#0E1012"))
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 0, 1.75)
	s.add_child(tail)
	var ts := _begin()
	_fin(ts, [Vector3(0, 0, 0), Vector3(0, 1.0, 0.75), Vector3(0, 0.75, 0.85), Vector3(0, 0.0, 0.35), Vector3(0, -0.55, 0.6), Vector3(0, -0.1, 0.1)], g)
	var tm := MeshInstance3D.new()
	tm.mesh = _commit(ts)
	tm.material_override = creature_mat()
	tail.add_child(tm)
	return s


# --- Things from the depths (Monster) --------------------------------------------
# Creepy dread, no gore (Blaney): big dark shapes with eyes that catch the light, a lure that
# glows in the black. Each nose to -Z; the parts that move are named so SeaLifeView sweeps them.

## A chain of tapering joints along +Z from `parent` (an arm, a tentacle, a serpent's body):
## each joint is a Node3D holding its segment and the next joint. Returns the joints.
static func _limb(parent: Node3D, length: float, r0: float, r1: float, segs: int, back: Color, belly: Color) -> Array[Node3D]:
	var joints: Array[Node3D] = []
	var at := parent
	var seg := length / segs
	for i in segs:
		var j := Node3D.new()
		if i > 0:
			j.position.z = seg
		at.add_child(j)
		var ra := lerpf(r0, r1, float(i) / segs)
		var rb := lerpf(r0, r1, float(i + 1) / segs)
		var st := _begin()
		_spindle(st, seg * 1.08, [[0.0, ra, ra], [1.0, rb, rb]], Vector3(0, 0, seg * 0.5), back, belly, 0.0, false, 8)
		var mi := MeshInstance3D.new()
		mi.mesh = _commit(st)
		mi.material_override = creature_mat()
		j.add_child(mi)
		joints.append(j)
		at = j
	return joints


## An eye that catches the light: a pale ball with a black slot, glowing a little in the dark.
static func _eye(parent: Node3D, r: float, pos: Vector3, glow: Color) -> void:
	Build.sphere(parent, r, pos, glow, 0.6)
	var pupil := Build.sphere(parent, r * 0.55, pos + Vector3(signf(pos.x) * r * 0.6, 0, 0), Color("#050506"))
	pupil.scale = Vector3(0.5, 1.0, 0.35)


## The giant squid, mantle first: a long dark red mantle with fins at its tip, the head with two
## eyes as big as a man, eight arms and two long tentacles with clubs trailing ("Arms").
static func squid(length := 40.0) -> Node3D:
	var n := Node3D.new()
	var back := Color("#5E2224")
	var belly := Color("#A35A50")
	var mantle := length * 0.38
	var st := _begin()
	_spindle(st, mantle, [[0.0, 0.0, 0.0], [0.12, 1.2, 1.2], [0.5, 2.4, 2.3], [0.85, 2.6, 2.5], [1.0, 2.3, 2.2]],
			Vector3(0, 0, -length * 0.5 + mantle * 0.5), back, belly, 0.0)
	for side in [-1.0, 1.0]: # the fins at the mantle's tip
		_fin(st, [Vector3(0, 0, -length * 0.5 + 0.5), Vector3(side * 4.5, 0, -length * 0.5 + 4.0), Vector3(side * 0.8, 0, -length * 0.5 + 7.5)], back.darkened(0.2))
	var head_z := -length * 0.5 + mantle + 1.5
	_spindle(st, 4.0, [[0.0, 2.2, 2.1], [0.5, 2.0, 1.9], [1.0, 1.3, 1.3]], Vector3(0, 0, head_z), back, belly, 0.0)
	var body := MeshInstance3D.new()
	body.mesh = _commit(st)
	body.material_override = creature_mat()
	n.add_child(body)
	for side in [-1.0, 1.0]:
		_eye(n, 0.9, Vector3(side * 1.9, 0.3, head_z - 0.3), Color("#C8D4C0"))
	var arms := Node3D.new()
	arms.name = "Arms"
	arms.position.z = head_z + 1.8
	n.add_child(arms)
	for k in 10:
		var a := TAU * k / 8.0
		var root := Node3D.new()
		var long := k >= 8 # the two hunting tentacles
		if long:
			a = PI * 0.5 + (k - 8) * PI
		root.position = Vector3(cos(a) * 1.0, sin(a) * 1.0, 0)
		root.rotation = Vector3(-sin(a) * 0.25, cos(a) * 0.25, 0)
		arms.add_child(root)
		var joints := _limb(root, length * (0.55 if long else 0.3), 0.55 if not long else 0.35, 0.08, 7 if long else 5, back, belly)
		if long:
			var club := Build.sphere(joints[-1], 0.9, Vector3(0, 0, length * 0.55 / 7.0), back)
			club.scale = Vector3(0.7, 0.5, 2.0)
	return n


## The giant anglerfish: a huge black round body and a gaping mouth of needle teeth, tiny dead
## eyes, and a rod off its head with a glowing lure hanging in front ("Lure").
static func angler(length := 28.0) -> Node3D:
	var n := Node3D.new()
	var back := Color("#16181C")
	var belly := Color("#2C2A30")
	var st := _begin()
	_spindle(st, length, [[0.0, 3.5, 3.0], [0.15, 6.5, 6.0], [0.4, 7.0, 6.5], [0.7, 4.0, 3.8], [0.9, 1.2, 1.4], [1.0, 0.6, 0.8]],
			Vector3.ZERO, back, belly, 0.0)
	_fin(st, [Vector3(0, 1.0, length * 0.38), Vector3(0, 5.5, length * 0.55), Vector3(0, -5.5, length * 0.55), Vector3(0, -1.0, length * 0.38)], back)
	for side in [-1.0, 1.0]:
		_fin(st, [Vector3(side * 6.0, -1.0, -length * 0.05), Vector3(side * 10.0, -3.0, length * 0.05), Vector3(side * 6.5, -2.0, length * 0.15)], back)
	var body := MeshInstance3D.new()
	body.mesh = _commit(st)
	body.material_override = creature_mat()
	n.add_child(body)
	# The mouth: a black gape across the front, needle teeth down from the top and up from the jaw.
	var mz := -length * 0.5 - 0.2
	Build.box(n, Vector3(9.0, 3.2, 1.0), Vector3(0, -1.2, mz + 0.8), Color("#020203"), false)
	var tooth := Color("#D8D4C4")
	for k in 13:
		var x := -4.2 + k * 0.7
		var top := Build.box(n, Vector3(0.12, 1.4 + 0.5 * sin(k * 2.3), 0.12), Vector3(x, 0.0, mz), tooth, false)
		top.rotation.x = 0.3
		var bottom := Build.box(n, Vector3(0.12, 1.2 + 0.6 * cos(k * 1.7), 0.12), Vector3(x + 0.35, -2.6, mz - 0.3), tooth, false)
		bottom.rotation.x = -0.4
	for side in [-1.0, 1.0]:
		_eye(n, 0.35, Vector3(side * 3.2, 2.0, -length * 0.38), Color("#9AA8A0"))
	var lure := Node3D.new()
	lure.name = "Lure"
	lure.position = Vector3(0, 5.5, -length * 0.3)
	n.add_child(lure)
	var rod := _limb(lure, 9.0, 0.18, 0.08, 4, back, belly)
	for j in rod:
		j.rotation.x = 0.35 # it arches up and over, forward
	rod[0].rotation.x = -1.2
	var bulb := Build.sphere(rod[-1], 0.7, Vector3(0, 0, 2.4), Color("#7CFFE0"), 4.0)
	var light := OmniLight3D.new()
	light.light_color = Color("#7CFFE0")
	light.light_energy = 1.6
	light.omni_range = 30.0
	bulb.add_child(light)
	return n


## The sea serpent: a long dark green body in segments ("Seg"), a long head with a frill and
## yellow eyes. SeaLifeView sends a wave down it.
static func serpent(length := 90.0) -> Node3D:
	var n := Node3D.new()
	var back := Color("#1D2E26")
	var belly := Color("#5C6A4E")
	var st := _begin()
	_spindle(st, 8.0, [[0.0, 0.5, 0.4], [0.3, 2.4, 1.8], [0.7, 3.2, 2.7], [1.0, 3.3, 3.1]], Vector3(0, 0, -length * 0.5 + 3.5), back, belly, -0.1)
	for k in 6: # the frill down the back of the head
		_fin(st, [Vector3(0, 1.5, -length * 0.5 + 3.0 + k * 0.8), Vector3(0, 3.2 - k * 0.2, -length * 0.5 + 3.6 + k * 0.8), Vector3(0, 1.6, -length * 0.5 + 4.0 + k * 0.8)], Color("#3A5A40"))
	var head := MeshInstance3D.new()
	head.mesh = _commit(st)
	head.material_override = creature_mat()
	n.add_child(head)
	for side in [-1.0, 1.0]:
		_eye(n, 0.4, Vector3(side * 1.2, 0.6, -length * 0.5 + 2.5), Color("#E8C840"))
	var spine := Node3D.new()
	spine.name = "Seg"
	spine.position.z = -length * 0.5 + 7.0
	n.add_child(spine)
	_limb(spine, length - 7.0, 3.3, 0.4, 18, back, belly)
	return n


## The megalodon: the shark, as long as a boat and darker.
static func megalodon(length := 45.0) -> Node3D:
	var s := shark()
	s.scale = Vector3.ONE * (length / 3.6)
	for m in s.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.material_override is ShaderMaterial:
			mi.material_override = mi.material_override.duplicate()
			(mi.material_override as ShaderMaterial).set_shader_parameter("albedo", Color("#6A6F74"))
	return s


static func monster(kind: String, length: float) -> Node3D:
	match kind:
		"angler":
			return angler(length)
		"serpent":
			return serpent(length)
		"megalodon":
			return megalodon(length)
	return squid(length)


# --- Sea-floor life and the gentler creatures (Blaney: "make the ocean feel more alive") ----
# Shapes for MultiMesh decor (SeaFloorLife): white or pale, tinted per instance, so one mesh
# draws every colour in a single call.

## A kelp frond, 1 m tall at scale 1 (scaled up to 6-14 m): a ribbon stalk with leaf blades
## off either side, root at the origin; it sways in `sway.gdshader`.
static func kelp_mesh() -> Mesh:
	var st := _begin()
	var segs := 8
	for i in segs:
		var y0 := float(i) / segs
		var y1 := float(i + 1) / segs
		var w := 0.012
		var x0 := sin(y0 * 5.0) * 0.03
		var x1 := sin(y1 * 5.0) * 0.03
		_fin(st, [Vector3(x0 - w, y0, 0), Vector3(x0 + w, y0, 0), Vector3(x1 + w, y1, 0), Vector3(x1 - w, y1, 0)], Color(0.85, 0.85, 0.8))
		if i > 0:
			var side := 1.0 if i % 2 == 0 else -1.0
			var c := Color(1, 1, 1)
			_fin(st, [Vector3(x0, y0, 0), Vector3(x0 + side * 0.09, y0 + 0.05, 0.02), Vector3(x0 + side * 0.13, y0 + 0.12, 0.03), Vector3(x0 + side * 0.02, y0 + 0.1, 0)], c)
	return _commit(st)


## A tuft of sea grass, 1 m tall at scale 1: a handful of thin blades leaning out.
static func grass_mesh() -> Mesh:
	var st := _begin()
	for k in 6:
		var a := k * TAU / 6.0 + 0.4
		var lean := Vector3(cos(a), 0, sin(a)) * 0.25
		var side := Vector3(-sin(a), 0, cos(a)) * 0.02
		var base := Vector3(cos(a), 0, sin(a)) * 0.04
		_fin(st, [base - side, base + side, base + lean * 0.5 + Vector3(0, 0.55, 0) + side * 0.6, base + lean + Vector3(0, 1.0 - k * 0.05, 0)], Color.WHITE)
	return _commit(st)


## A starfish lying on the bottom, 1 m across at scale 1: five plump arms.
static func starfish_mesh() -> Mesh:
	var st := _begin()
	for k in 5:
		var a := k * TAU / 5.0
		var b := a + TAU / 10.0
		var c := a - TAU / 10.0
		var tip := Vector3(cos(a), 0.02, sin(a)) * 0.5
		var top := Vector3(0, 0.08, 0)
		var l := Vector3(cos(b), 0.0, sin(b)) * 0.12
		var r := Vector3(cos(c), 0.0, sin(c)) * 0.12
		_ctri(st, [top, l, tip], [Color.WHITE, Color.WHITE, Color.WHITE], Vector3.UP)
		_ctri(st, [top, tip, r], [Color.WHITE, Color.WHITE, Color.WHITE], Vector3.UP)
	return _commit(st)


## A crab, 1 m across at scale 1 (placed at a tenth of that): a flat round shell, legs, claws.
static func crab_mesh() -> Mesh:
	var st := _begin()
	_spindle(st, 0.45, [[0.0, 0.0, 0.0], [0.2, 0.25, 0.08], [0.6, 0.28, 0.1], [1.0, 0.0, 0.0]], Vector3(0, 0.12, 0), Color(0.9, 0.9, 0.9), Color.WHITE, 0.0, false, 8)
	for side in [-1.0, 1.0]:
		for k in 3:
			var z := -0.1 + k * 0.1
			_fin(st, [Vector3(side * 0.2, 0.12, z), Vector3(side * 0.42, 0.18, z + 0.02), Vector3(side * 0.5, 0.0, z + 0.05), Vector3(side * 0.4, 0.15, z + 0.05)], Color(0.8, 0.8, 0.8))
		_fin(st, [Vector3(side * 0.12, 0.12, -0.2), Vector3(side * 0.25, 0.16, -0.38), Vector3(side * 0.14, 0.14, -0.45), Vector3(side * 0.08, 0.1, -0.3)], Color.WHITE) # a claw
	return _commit(st)


## A tube sponge, 1 m tall at scale 1: a few open-topped tubes in a clump.
static func sponge_mesh() -> Mesh:
	var st := _begin()
	for k in 3:
		var at := Vector3(cos(k * 2.1) * 0.15, 0, sin(k * 2.1) * 0.15) * (0.0 if k == 0 else 1.0)
		var h := 1.0 - k * 0.25
		var r := 0.12 - k * 0.02
		var n := 8
		for i in n:
			var a0 := i * TAU / n
			var a1 := (i + 1) * TAU / n
			var p0 := at + Vector3(cos(a0) * r, 0, sin(a0) * r)
			var p1 := at + Vector3(cos(a1) * r, 0, sin(a1) * r)
			var c := Color.WHITE
			var d := Color(0.55, 0.55, 0.55) # dark inside
			_ctri(st, [p0, p1, p1 + Vector3(0, h, 0)], [c, c, c], (p0 - at))
			_ctri(st, [p0, p1 + Vector3(0, h, 0), p0 + Vector3(0, h, 0)], [c, c, c], (p0 - at))
			_ctri(st, [p0, p1, p1 + Vector3(0, h, 0)], [d, d, d], -(p0 - at))
			_ctri(st, [p0, p1 + Vector3(0, h, 0), p0 + Vector3(0, h, 0)], [d, d, d], -(p0 - at))
	return _commit(st)


## A jellyfish, 1 m across: a see-through glowing bell with frilly tentacles trailing down
## ("Bell" pulses, SeaLifeView). It glows on its own, so in the black it's the only thing seen.
static func jellyfish(glow: Color) -> Node3D:
	var j := Node3D.new()
	var bell := MeshInstance3D.new()
	bell.name = "Bell"
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 0.6
	sm.is_hemisphere = true
	sm.radial_segments = 12
	sm.rings = 4
	bell.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(glow, 0.55)
	bell.material_override = m
	j.add_child(bell)
	var st := _begin()
	for k in 8:
		var a := k * TAU / 8.0
		var r := 0.35
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var w := Vector3(-sin(a), 0, cos(a)) * 0.03
		_fin(st, [p - w, p + w, p * 0.8 + Vector3(0, -1.6 - k % 3 * 0.4, 0)], Color.WHITE)
	var tails := MeshInstance3D.new()
	tails.name = "Tails"
	tails.mesh = _commit(st)
	var tm := m.duplicate() as StandardMaterial3D
	tm.albedo_color = Color(glow, 0.3)
	tails.material_override = tm
	j.add_child(tails)
	return j


## A manta ray, about 5 m across, nose to -Z: a flat dark diamond, pale below, with two wings
## ("WingL"/"WingR", which flap) and a thin tail.
static func manta() -> Node3D:
	var r := Node3D.new()
	var back := Color("#2B3138")
	var belly := Color("#DDE2E4")
	var st := _begin()
	_spindle(st, 2.6, [[0.0, 0.0, 0.0], [0.15, 0.45, 0.18], [0.5, 0.6, 0.25], [0.85, 0.3, 0.12], [1.0, 0.05, 0.03]], Vector3.ZERO, back, belly, 0.0)
	_fin(st, [Vector3(0, 0, 1.2), Vector3(0.03, 0, 3.4), Vector3(-0.03, 0, 3.4)], back) # tail
	for side in [-1.0, 1.0]: # the horns by the mouth
		_fin(st, [Vector3(side * 0.35, 0, -1.2), Vector3(side * 0.42, -0.05, -1.65), Vector3(side * 0.25, 0, -1.25)], back)
	var body := MeshInstance3D.new()
	body.mesh = _commit(st)
	body.material_override = creature_mat()
	r.add_child(body)
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.name = "WingL" if side < 0.0 else "WingR"
		wing.position = Vector3(side * 0.5, 0, -0.1)
		r.add_child(wing)
		var ws := _begin()
		var tri := [Vector3(0, 0, -0.9), Vector3(side * 2.2, 0.05, 0.3), Vector3(0, 0, 0.9)]
		_ctri(ws, tri, [back, back, back], Vector3.UP)
		_ctri(ws, tri, [belly, belly, belly], Vector3.DOWN)
		var wm := MeshInstance3D.new()
		wm.mesh = _commit(ws)
		wm.material_override = creature_mat()
		wing.add_child(wm)
	return r


## A sea turtle, about 1.2 m, nose to -Z: a domed olive shell, a head, four flippers
## ("Flip0".."Flip3": the front two row, the back two steer).
static func turtle() -> Node3D:
	var t := Node3D.new()
	var shell := Color("#5E6B3A")
	var skin := Color("#8D9A6A")
	var st := _begin()
	_spindle(st, 1.1, [[0.0, 0.0, 0.0], [0.15, 0.35, 0.18], [0.5, 0.45, 0.25], [0.85, 0.3, 0.14], [1.0, 0.0, 0.0]], Vector3.ZERO, shell, Color("#C9B98A"), -0.3)
	var body := MeshInstance3D.new()
	body.mesh = _commit(st)
	body.material_override = creature_mat()
	t.add_child(body)
	var head := Build.sphere(t, 0.14, Vector3(0, 0.02, -0.66), skin)
	head.scale = Vector3(1.0, 0.8, 1.3)
	for k in 4:
		var side := -1.0 if k % 2 == 0 else 1.0
		var front := k < 2
		var f := Node3D.new()
		f.name = "Flip%d" % k
		f.position = Vector3(side * 0.3, -0.02, -0.25 if front else 0.35)
		t.add_child(f)
		var fs := _begin()
		var len := 0.7 if front else 0.3
		_fin(fs, [Vector3(0, 0, -0.08), Vector3(side * len, 0, 0.1), Vector3(side * len * 0.8, 0, 0.2), Vector3(0, 0, 0.08)], skin)
		var fm := MeshInstance3D.new()
		fm.mesh = _commit(fs)
		fm.material_override = creature_mat()
		f.add_child(fm)
	return t
