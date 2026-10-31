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
