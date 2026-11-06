class_name CaveView
extends RefCounted
## A cave from the Seabed, drawn: the rock ridge standing out of the water, cliffs down to its
## foot, and the S-bend tunnel through it as a lofted rock tube with the mouth cut in each end
## face. Dark rock inside, lit by soft blue-green glowing spots on the walls (Blaney's creepy
## dread down deep, but enough to steer by).

const RING := 16 ## points round the tunnel's cross-section
const STEP := 10.0 ## m between rings along it
const GLOWS := 70
const SQUARE := 6.0 ## how square the tube's section is (2 is an ellipse): it hugs the room the sim gives her
const ROCK: Array[Color] = [Color("#3B3F44"), Color("#45423C"), Color("#353A40"), Color("#4A4C4A")]
const GLOW: Array[Color] = [Color("#4FF0D0"), Color("#5FC8FF"), Color("#9BE564")]


static func build(f: Dictionary, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "Cave"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var half := float(f.len) * 0.5
	var rings: Array = []
	var n := int(float(f.len) / STEP)
	for i in n + 1:
		rings.append(_ring(f, -half + i * STEP, rng, i == 0 or i == n))
	for i in n:
		for k in RING:
			var k2 := (k + 1) % RING
			_quad(st, rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k], rng, true)
	_ridge(st, f, rings, rng)
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = Build.terrain_mat()
	root.add_child(m)
	_glows(root, f, rng)
	return root


## The tunnel's section `u` m along: a squared-off ellipse just outside the room the sim gives,
## a little rough (but never inside it); the two end rings smooth, to meet the mouth.
static func _ring(f: Dictionary, u: float, rng: RandomNumberGenerator, smooth: bool) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var roof := Seabed.cave_roof(f, u)
	var bottom := Seabed.cave_bottom(f, u)
	var mid := (roof + bottom) * 0.5
	var hh := (bottom - roof) * 0.5
	var hw := float(f.w) * 0.5
	var cv := Seabed.cave_centre(f, u)
	for k in RING:
		var a := TAU * k / RING
		var ca := cos(a)
		var sa := sin(a)
		var grow := 1.04 if smooth else rng.randf_range(1.05, 1.2)
		var x := signf(ca) * pow(absf(ca), 2.0 / SQUARE) * hw * grow
		var y := signf(sa) * pow(absf(sa), 2.0 / SQUARE) * hh * grow
		out.append(_p3(f, u, cv + x, mid + y))
	return out


static func _p3(f: Dictionary, u: float, v: float, depth: float) -> Vector3:
	var p := Seabed.cave_world(f, Vector2(u, v))
	return Vector3(p.x, -depth, -p.y)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, rng: RandomNumberGenerator, inside: bool) -> void:
	var col := ROCK[rng.randi() % ROCK.size()]
	if not inside:
		col = col.lightened(0.15)
	for v in [a, b, c, a, c, d]:
		st.set_color(col)
		st.add_vertex(v)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	for v in [a, b, c]:
		st.set_color(col)
		st.add_vertex(v)


## The ridge: a rough top standing out of the water, cliffs down its long sides to the foot, the
## end faces round the mouths, and the floor it stands on.
static func _ridge(st: SurfaceTool, f: Dictionary, rings: Array, rng: RandomNumberGenerator) -> void:
	var half := float(f.len) * 0.5
	var ridge := float(f.ridge)
	var land := float(f.land) # negative: above the water
	var foot := float(f.foot)
	var nu := 14
	var nv := 30
	var top := func(i: int, j: int) -> Vector3:
		var edge := i == 0 or i == nu or j == 0 or j == nv
		var lift := 0.0 if edge else hash([f.x, i, j]) % 1000 / 1000.0 * 40.0
		return _p3(f, -half + float(i) / nu * half * 2.0, -ridge + float(j) / nv * ridge * 2.0, land - lift)
	for i in nu:
		for j in nv:
			var col := Color("#5E5A50").lerp(Color("#3E5E3A"), rng.randf() * 0.5)
			_tri(st, top.call(i, j), top.call(i, j + 1), top.call(i + 1, j + 1), col)
			_tri(st, top.call(i, j), top.call(i + 1, j + 1), top.call(i + 1, j), col)
	for side in [-1.0, 1.0]: # the long cliffs across the ends of the ridge
		for i in nu:
			var u0 := -half + float(i) / nu * half * 2.0
			var u1 := u0 + half * 2.0 / nu
			var a := _p3(f, u0, side * ridge, land)
			var b := _p3(f, u1, side * ridge, land)
			var c := _p3(f, u1, side * ridge, foot)
			var d := _p3(f, u0, side * ridge, foot)
			if side > 0.0:
				_quad(st, a, b, c, d, rng, false)
			else:
				_quad(st, a, d, c, b, rng, false)
	_end_face(st, f, rings[0], -half, rng)
	_end_face(st, f, rings[rings.size() - 1], half, rng)
	var r := maxf(half, ridge) + 900.0 # the floor round it
	var c0 := Vector2(f.x, f.y)
	var fl := Color("#22424F")
	var corners: Array[Vector3] = []
	for o: Vector2 in [Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)]:
		corners.append(Vector3(c0.x + o.x, -foot - 0.5, -(c0.y + o.y)))
	_tri(st, corners[0], corners[2], corners[1], fl)
	_tri(st, corners[0], corners[3], corners[2], fl)


## One end face of the ridge (`u` = ±len/2), from the ridge's edges in to its mouth: four slabs
## round a square hole, then the gap between the hole and the round mouth stitched shut.
static func _end_face(st: SurfaceTool, f: Dictionary, ring: Array, u: float, rng: RandomNumberGenerator) -> void:
	var ridge := float(f.ridge)
	var land := float(f.land)
	var foot := float(f.foot)
	var roof := Seabed.cave_roof(f, u)
	var bottom := Seabed.cave_bottom(f, u)
	var hw := float(f.w) * 0.5 * 1.1
	var mid := (roof + bottom) * 0.5
	var hh := (bottom - roof) * 0.5 * 1.1
	var facing := u > 0.0
	var slab := func(v0: float, v1: float, d0: float, d1: float) -> void:
		var a := _p3(f, u, v0, d0)
		var b := _p3(f, u, v1, d0)
		var c := _p3(f, u, v1, d1)
		var d := _p3(f, u, v0, d1)
		if facing:
			_quad(st, a, d, c, b, rng, false)
		else:
			_quad(st, a, b, c, d, rng, false)
	slab.call(-ridge, -hw, land, foot)
	slab.call(hw, ridge, land, foot)
	slab.call(-hw, hw, land, mid - hh)
	slab.call(-hw, hw, mid + hh, foot)
	# The hole's edge, as points round it by angle, corners included; each joined to the ring
	# point nearest its angle.
	var edge: Array = [] # [angle, Vector3]
	for k in RING:
		var a := TAU * k / RING
		var dir := Vector2(cos(a) / hw, sin(a) / hh)
		var s := 1.0 / maxf(absf(dir.x), absf(dir.y))
		edge.append([a, _p3(f, u, cos(a) * s, mid + sin(a) * s)])
	for c: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]:
		edge.append([fposmod(atan2(c.y * hh, c.x * hw), TAU), _p3(f, u, c.x * hw, mid + c.y * hh)])
	edge.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var col := ROCK[0]
	for i in edge.size():
		var e0: Array = edge[i]
		var e1: Array = edge[(i + 1) % edge.size()]
		var r0 := roundi(float(e0[0]) / TAU * RING) % RING
		var r1 := roundi(float(e1[0]) / TAU * RING) % RING
		if facing:
			_tri(st, e0[1], ring[r1], e1[1], col)
			if r0 != r1:
				_tri(st, e0[1], ring[r0], ring[r1], col)
		else:
			_tri(st, e0[1], e1[1], ring[r1], col)
			if r0 != r1:
				_tri(st, e0[1], ring[r1], ring[r0], col)


## Soft glowing spots (sea anemones, glow worms) on the walls and roof all through.
static func _glows(root: Node3D, f: Dictionary, rng: RandomNumberGenerator) -> void:
	var half := float(f.len) * 0.5
	for i in GLOWS:
		var u := rng.randf_range(-half, half)
		var a := rng.randf_range(PI * 1.05, PI * 1.95) if rng.randf() < 0.5 else (0.0 if rng.randf() < 0.5 else PI) + rng.randf_range(-0.5, 0.5)
		var roof := Seabed.cave_roof(f, u)
		var bottom := Seabed.cave_bottom(f, u)
		var hw := float(f.w) * 0.5 * 1.04
		var hh := (bottom - roof) * 0.5 * 1.04
		var x := signf(cos(a)) * pow(absf(cos(a)), 2.0 / SQUARE) * hw
		var y := signf(sin(a)) * pow(absf(sin(a)), 2.0 / SQUARE) * hh
		Build.sphere(root, rng.randf_range(0.5, 1.4), _p3(f, u, Seabed.cave_centre(f, u) + x, (roof + bottom) * 0.5 + y), GLOW[rng.randi() % GLOW.size()], 3.0)
