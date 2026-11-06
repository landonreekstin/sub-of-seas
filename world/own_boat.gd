class_name OwnBoat
## Our own boat from outside (Blaney: "a better outside of the sub: real details, smoother hull
## shape, weathered paint; good functioning outsides of all the subs to the extent that they
## exist in real life, the typhoon most"). One shape, `dims()`, drives the model here and what
## the crew walk and swim against out on deck (Deck): a lofted hull whose sections are
## superellipses cut flat by the casing, and a streamlined fin. z runs bow (-) to stern (+), y up
## from the waterline; t is the station from the stem (0) to the tail (1).
##
## The gun is the node "Gun" (it trains about y), its barrel "Gun/Barrel" (recoils along +z),
## the muzzle "Gun/Barrel/Muzzle" and the gunlayer's eye "Gun/Eye".

const RUBBER := Color("#1B1D1F") ## a Typhoon's anechoic tiles, sides and fin
const RUBBER_DECK := Color("#232527") ## and her deck, worn a shade lighter by feet
const BARE := Color("#43484B") ## where tiles have come away
const HULL := Color("#2C3034") ## WWII dark grey
const FIN := Color("#33373C")
const RUST := Color("#74402A")
const SALT := Color("#A7ACA4")
const BOOT := Color("#121314") ## below the waterline, and holes in the casing
const STEEL := Color("#3A3F44")
const RAIL := Color("#8A8F86")
const WHITE := Color("#E8E4DA")
const RING := 44 ## points round a hull section
const STATIONS := 90
const NUMBERS := {"s_boat": "S-44", "gato": "SS-212", "narwhal": "SS-167"}


static func dims(sub: SubClassData) -> Dictionary:
	var l := sub.length
	var ty := sub.key == "typhoon"
	if sub.key == "titan": # small, and nobody walks on her
		return {"key": sub.key, "typhoon": false, "length": sub.length, "beam": sub.beam, "deck": 1.1, "draft": 1.4, "n": 2.0, "k": 0.3,
			"bow": 0.3, "tail": 0.7, "ct_z": 0.0, "ct_len": 1.0, "ct_h": 0.2, "guns": false, "a": sub.beam * 0.5, "b": 1.25, "yc": -0.15,
			"ct_w": 0.8, "gun_z": -2.0, "hatch_z": -1.5, "ladder_z": 1.5, "ring_z": 2.0, "ring_edge": 0.5}
	var d := {"key": sub.key, "typhoon": ty, "length": l,
		"beam": 23.0 if ty else clampf(l * 0.088, 6.0, 10.0),
		"deck": 5.0 if ty else clampf(l * 0.028, 2.2, 3.2),
		"draft": 11.0 if ty else clampf(l * 0.05, 3.6, 5.0),
		"n": 3.2 if ty else 2.4, # squarer sections: her two pressure hulls side by side
		"k": 0.72 if ty else 0.5, # how much of the beam the flat casing takes
		"bow": 0.14 if ty else 0.2, "tail": 0.72 if ty else 0.78,
		"ct_z": l * 0.12 if ty else -l * 0.06, "ct_len": l * 0.16, "ct_h": 12.0 if ty else 4.2,
		"guns": sub.gun_rounds > 0}
	var n: float = d.n
	var q := pow(1.0 - pow(float(d.k), n), 1.0 / n)
	d.a = float(d.beam) * 0.5
	d.b = (float(d.deck) + float(d.draft)) / (1.0 + q)
	d.yc = float(d.b) - float(d.draft)
	d.ct_w = float(d.beam) * 0.32
	var front := float(d.ct_z) - float(d.ct_len) * 0.5
	d.gun_z = front - 6.0
	d.hatch_z = front - 2.6 # the deck hatch, just forward of the fin, clear of it
	d.ladder_z = float(d.ct_z) + float(d.ct_len) * 0.5 + 3.0 # rungs up the side from the water
	d.ring_z = float(d.ladder_z) + 6.0 # the wrestling ring painted across the aft casing
	d.ring_edge = deck_half(d, t_of(d, d.ring_z)) - 0.15
	return d


static func t_of(d: Dictionary, z: float) -> float:
	return (z + float(d.length) * 0.5) / float(d.length)


## How full her sections are at t: a rounded bow, parallel amidships, tapering to the screws.
static func _p(d: Dictionary, t: float) -> float:
	var bow: float = d.bow
	var tail: float = d.tail
	if t < bow:
		return pow(maxf(0.0, 1.0 - pow(1.0 - t / bow, 2.0)), 0.5 if d.typhoon else 0.75)
	if t > tail:
		return maxf(0.05, 1.0 - pow((t - tail) / (1.0 - tail), 1.7))
	return 1.0


static func _yc(d: Dictionary, t: float) -> float: # her axis rises a little... and drops to the shafts
	return lerpf(float(d.yc), -float(d.draft) * (0.22 if d.typhoon else 0.4), smoothstep(float(d.tail), 1.0, t))


static func _b(d: Dictionary, t: float) -> float:
	return float(d.b) * lerpf(1.0, _p(d, t), 0.75)


## The casing's height at t: a WWII boat's sheer rises to her bow, a Typhoon's is flat.
static func deck_y(d: Dictionary, t: float) -> float:
	var fb: float = d.deck
	return fb if d.typhoon else fb + fb * 0.22 * pow(maxf(0.0, 1.0 - t / 0.18), 2.0)


## Half the hull's width at station t, height y (0 if y is above or below her there).
static func half_at(d: Dictionary, t: float, y: float) -> float:
	var r := absf((y - _yc(d, t)) / _b(d, t))
	if r >= 1.0:
		return 0.0
	var n: float = d.n
	return float(d.a) * _p(d, t) * pow(1.0 - pow(r, n), 1.0 / n)


## Half the walkable casing's width at t.
static func deck_half(d: Dictionary, t: float) -> float:
	return half_at(d, t, deck_y(d, t))


## A point on her skin at t, angle `ang` round the section (0 starboard, PI/2 up).
static func section(d: Dictionary, t: float, ang: float) -> Vector3:
	var n: float = d.n
	var c := cos(ang)
	var s := sin(ang)
	var x := float(d.a) * _p(d, t) * signf(c) * pow(absf(c), 2.0 / n)
	var y := _yc(d, t) + _b(d, t) * signf(s) * pow(absf(s), 2.0 / n)
	return Vector3(x, minf(y, deck_y(d, t)), -float(d.length) * 0.5 + t * float(d.length))


## Half the fin's width at s (0 its nose, 1 its after end), in plan.
static func fin_half(d: Dictionary, s: float) -> float:
	var w := float(d.ct_w) * 0.5
	var nose := 0.3 if d.typhoon else 0.22
	if s < nose:
		return w * sqrt(maxf(0.0, 1.0 - pow(1.0 - s / nose, 2.0)))
	var aft := 0.5 if d.typhoon else 0.6
	if s > aft:
		return w * (1.0 - (0.8 if d.typhoon else 0.45) * pow((s - aft) / (1.0 - aft), 1.6))
	return w


## The fin's height above the deck at s: a WWII boat's steps down aft to the cigarette deck.
static func fin_h(d: Dictionary, s: float) -> float:
	var h: float = d.ct_h
	if d.typhoon:
		return h * lerpf(1.0, 0.82, smoothstep(0.55, 1.0, s))
	return h if s < 0.62 else h * 0.62


static func _station(i: int) -> float: # closer together at the ends, where she curves most
	return 0.5 - 0.5 * cos(PI * float(i) / float(STATIONS))


static func _hash(a: float, b: float) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0)


static func build(sub: SubClassData) -> Node3D:
	var root := Node3D.new()
	root.name = "OwnBoat"
	if sub.key == "titan":
		_titan(root, sub)
		return root
	var d := dims(sub)
	var kit := {}
	_hull(root, d)
	_deck(root, d)
	_fin(root, d)
	if d.typhoon:
		_typhoon_gear(kit, d)
	else:
		_wwii_gear(root, kit, d)
	_gun(root, sub, d)
	_common(kit, d)
	_commit(root, kit)
	return root


## The hull, painted by vertex colour: weathered grey with rust running down from the casing,
## salt at the waterline and black below it (WWII); black rubber tiles, some missing, on a Typhoon.
static func _hull(root: Node3D, d: Dictionary) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	var cols: Array = []
	for i in STATIONS + 1:
		var t := _station(i)
		var ring: Array[Vector3] = []
		var col: Array[Color] = []
		var top := deck_y(d, t)
		for k in RING:
			var p := section(d, t, TAU * k / RING)
			ring.append(p)
			col.append(_hull_paint(d, i, k, p, top))
		rings.append(ring)
		cols.append(col)
	for i in STATIONS:
		for k in RING:
			var k2 := (k + 1) % RING
			var a: Vector3 = rings[i][k]
			var b: Vector3 = rings[i + 1][k]
			var c: Vector3 = rings[i + 1][k2]
			var e: Vector3 = rings[i][k2]
			_vtri(st, [a, b, c], [cols[i][k], cols[i + 1][k], cols[i + 1][k2]], (a + c) * 0.5 - Vector3(0, _yc(d, _station(i)), a.z))
			_vtri(st, [a, c, e], [cols[i][k], cols[i + 1][k2], cols[i][k2]], (a + c) * 0.5 - Vector3(0, _yc(d, _station(i)), a.z))
	var last: Array = rings[STATIONS] # a cap over the tail
	var mid := Vector3(0, _yc(d, 1.0), float(d.length) * 0.5)
	for k in RING:
		_vtri(st, [last[k], last[(k + 1) % RING], mid], [cols[STATIONS][k], cols[STATIONS][k], cols[STATIONS][k]], Vector3.BACK)
	st.index()
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Hull"
	mi.mesh = st.commit()
	mi.material_override = _painted()
	root.add_child(mi)


static func _hull_paint(d: Dictionary, i: int, k: int, p: Vector3, top: float) -> Color:
	if d.typhoon:
		var c := RUBBER
		if _hash(i * 0.37, k * 1.3) > 0.94 and p.y < top - 0.3:
			c = BARE # tiles torn off
		if p.y > -0.3 and p.y < 0.5:
			c = c.lerp(SALT, 0.12)
		return c
	if p.y < -0.12:
		return BOOT
	var c := HULL
	var side := signf(p.x)
	var h := _hash(float(i), side)
	if h > 0.8: # rust bleeding down from the limber holes and fittings
		c = c.lerp(RUST, clampf(1.0 - (top - p.y) / 2.4, 0.0, 1.0) * (h - 0.8) / 0.2 * 0.85)
	if p.y < 0.45:
		c = c.lerp(SALT, 0.18 * (1.0 - p.y / 0.45))
	return c.lerp(Color.BLACK, 0.12 * _hash(float(i) * 0.1, float(k)))


static func _painted() -> Material:
	var m := (Build.mat(STEEL) as ShaderMaterial).duplicate() as ShaderMaterial
	m.set_shader_parameter("albedo", Color.WHITE)
	m.set_shader_parameter("vertex_color", true)
	m.set_shader_parameter("roughness", 0.95) # weathered paint and rubber: no shine
	return m


static func _vtri(st: SurfaceTool, p: Array, c: Array, out: Vector3) -> void:
	var n := (Vector3(p[1]) - Vector3(p[0])).cross(Vector3(p[2]) - Vector3(p[0]))
	if n.length_squared() < 1e-10:
		return
	var order := [0, 1, 2] if n.dot(out) <= 0.0 else [0, 2, 1] # front faces wind clockwise
	for j in order:
		st.set_color(c[j])
		st.add_vertex(p[j])


## The casing's deck: teak planks on a WWII boat, black rubber on a Typhoon.
static func _deck(root: Node3D, d: Dictionary) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in STATIONS:
		var ta := _station(i)
		var tb := _station(i + 1)
		var wa := deck_half(d, ta) * 0.96
		var wb := deck_half(d, tb) * 0.96
		if wa < 0.05 and wb < 0.05:
			continue
		var za := -float(d.length) * 0.5 + ta * float(d.length)
		var zb := -float(d.length) * 0.5 + tb * float(d.length)
		var ya := deck_y(d, ta) + 0.02
		var yb := deck_y(d, tb) + 0.02
		var a := Vector3(wa, ya, za)
		var b := Vector3(wb, yb, zb)
		ShipModels._tri(st, a, b, b * Vector3(-1, 1, 1), Vector3.UP)
		ShipModels._tri(st, a, b * Vector3(-1, 1, 1), a * Vector3(-1, 1, 1), Vector3.UP)
	st.index()
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Casing"
	mi.mesh = st.commit()
	mi.material_override = Build.mat(RUBBER_DECK if d.typhoon else ShipModels.DECK)
	root.add_child(mi)


## The fin (the fairwater round the conning tower and bridge): a streamlined shape in plan,
## its top edge rounded, streaked by the weather.
static func _fin(root: Node3D, d: Dictionary) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z0 := float(d.ct_z) - float(d.ct_len) * 0.5
	var y0 := deck_y(d, t_of(d, z0)) - 0.4
	var r := 1.4 if d.typhoon else 0.35 # the rounded top edge
	var steps := 40
	var rows: Array = [] # per s: round from the port foot, up, over the top, down to the starboard foot
	var cols: Array = []
	for j in steps + 1:
		var s := float(j) / steps
		var z := z0 + s * float(d.ct_len)
		var h := y0 + 0.4 + fin_h(d, s)
		var w := maxf(fin_half(d, s), 0.02)
		var prof := [[y0, 1.0], [h - r, 1.0], [h - r * 0.3, 0.93], [h, 0.78 if d.typhoon else 0.9]]
		var row: Array[Vector3] = []
		var col: Array[Color] = []
		for side: float in [-1.0, 1.0]:
			var lv := prof.duplicate()
			if side > 0.0:
				lv.reverse()
			for L: Array in lv:
				var y: float = L[0]
				row.append(Vector3(side * w * float(L[1]), y, z))
				var c := RUBBER if d.typhoon else FIN
				var hh := _hash(float(j), side * 3.0)
				if not d.typhoon and hh > 0.72:
					c = c.lerp(RUST, clampf(1.0 - (h - y) / 3.0, 0.0, 1.0) * 0.7)
				elif d.typhoon and hh > 0.85:
					c = c.lerp(SALT, clampf(1.0 - (h - y) / 6.0, 0.0, 1.0) * 0.3)
				col.append(c)
		rows.append(row)
		cols.append(col)
	var m: int = rows[0].size()
	for j in steps:
		for k in m:
			var k2 := (k + 1) % m
			var a: Vector3 = rows[j][k]
			var b: Vector3 = rows[j + 1][k]
			var c: Vector3 = rows[j + 1][k2]
			var e: Vector3 = rows[j][k2]
			var out := ((a + c) * 0.5 - Vector3(0, y0 + float(d.ct_h) * 0.5, 0)) * Vector3(1, 1, 0)
			_vtri(st, [a, b, c], [cols[j][k], cols[j + 1][k], cols[j + 1][k2]], out)
			_vtri(st, [a, c, e], [cols[j][k], cols[j + 1][k2], cols[j][k2]], out)
	for j in [0, steps]: # close the ends
		var cen := Vector3.ZERO
		for p: Vector3 in rows[j]:
			cen += p / m
		for k in m:
			_vtri(st, [rows[j][k], rows[j][(k + 1) % m], cen], [cols[j][k], cols[j][k], cols[j][k]], Vector3.FORWARD if j == 0 else Vector3.BACK)
	st.index()
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Fin"
	mi.mesh = st.commit()
	mi.material_override = _painted()
	root.add_child(mi)


## Details batched into one mesh per colour: `kit` maps a colour to a SurfaceTool.
static func _bx(kit: Dictionary, col: Color, size: Vector3, pos: Vector3, basis := Basis.IDENTITY) -> void:
	var key := col.to_html()
	if not kit.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		kit[key] = [st, col]
	var st: SurfaceTool = kit[key][0]
	var h := size * 0.5
	var c := func(x: float, y: float, z: float) -> Vector3: return pos + basis * Vector3(x * h.x, y * h.y, z * h.z)
	for f in [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
			[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
			[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]]:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var p := [n + u + v, n - u + v, n - u - v, n + u - v]
		var q: Array[Vector3] = []
		for x: Vector3 in p:
			q.append(c.call(x.x, x.y, x.z))
		ShipModels._tri(st, q[0], q[1], q[2], basis * n)
		ShipModels._tri(st, q[0], q[2], q[3], basis * n)


## A bar from a to b.
static func _bar(kit: Dictionary, col: Color, a: Vector3, b: Vector3, thick: float) -> void:
	var dir := b - a
	if dir.length() < 0.01:
		return
	var z := dir.normalized()
	var up := Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT
	var x := up.cross(z).normalized()
	_bx(kit, col, Vector3(thick, thick, dir.length()), (a + b) * 0.5, Basis(x, z.cross(x), z))


static func _commit(root: Node3D, kit: Dictionary) -> void:
	for key: String in kit:
		var st: SurfaceTool = kit[key][0]
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = Build.mat(kit[key][1])
		root.add_child(mi)


static func _z(d: Dictionary, t: float) -> float:
	return -float(d.length) * 0.5 + t * float(d.length)


## A WWII fleet boat's or S-boat's gear: limber holes along the casing, lifelines, bow and
## stern planes, rudder, twin screws, an anchor, the bridge, shears, radar and the hull number.
static func _wwii_gear(root: Node3D, kit: Dictionary, d: Dictionary) -> void:
	var l: float = d.length
	# Limber holes: the casing is free-flooding, so rows of slots let the sea in and out.
	var z := _z(d, 0.1)
	while z < _z(d, 0.88):
		var t := t_of(d, z)
		if absf(z - float(d.ladder_z)) > 0.7:
			var y := deck_y(d, t) - 0.38
			for side: float in [-1.0, 1.0]:
				_bx(kit, BOOT, Vector3(0.08, 0.2, 0.42), Vector3(side * half_at(d, t, y), y, z))
		z += 0.72
	# Stanchions and two lifelines down each side of the casing.
	var posts: Array[float] = []
	z = _z(d, 0.1)
	while z < _z(d, 0.86):
		if absf(z - float(d.ct_z)) > float(d.ct_len) * 0.5 + 0.8:
			posts.append(z)
		z += 2.4
	for side: float in [-1.0, 1.0]:
		var prev := Vector3.INF
		for pz in posts:
			var t := t_of(d, pz)
			var base := Vector3(side * (deck_half(d, t) - 0.1), deck_y(d, t), pz)
			_bx(kit, RAIL, Vector3(0.05, 0.95, 0.05), base + Vector3(0, 0.47, 0))
			if prev != Vector3.INF and pz - prev.z < 2.6:
				for hy: float in [0.5, 0.93]:
					_bar(kit, RAIL, prev + Vector3(0, hy, 0), base + Vector3(0, hy, 0), 0.025)
			prev = base
	# Bow planes rigged out, the anchor in its pocket.
	var tb := 0.075
	for side: float in [-1.0, 1.0]:
		var hw := half_at(d, tb, 0.5)
		_bx(kit, STEEL, Vector3(2.0, 0.12, 1.0), Vector3(side * (hw + 0.95), 0.5, _z(d, tb)))
		_bx(kit, BOOT, Vector3(0.12, 0.7, 0.7), Vector3(side * half_at(d, 0.05, 1.2), 1.2, _z(d, 0.05)))
	# Stern planes, rudder, shafts and twin screws.
	var ts := 0.955
	var yc := _yc(d, ts)
	for side: float in [-1.0, 1.0]:
		var hw := half_at(d, ts, yc)
		_bx(kit, STEEL, Vector3(2.4, 0.12, 1.4), Vector3(side * (hw + 1.1), yc, _z(d, ts)))
		var sx := side * float(d.beam) * 0.15
		var sz := _z(d, 0.99) + 0.6
		_bar(kit, STEEL, Vector3(sx, yc - 0.3, _z(d, 0.9)), Vector3(sx, yc - 0.3, sz), 0.2)
		_screw(kit, Vector3(sx, yc - 0.3, sz), clampf(float(d.beam) * 0.13, 0.8, 1.2), 4)
	_bx(kit, STEEL, Vector3(0.16, 2.6, 1.8), Vector3(0, yc - 0.8, _z(d, 1.0) + 1.0))
	# The bridge on top of the fin: a dark cockpit, its rim, a windscreen; periscope shears,
	# the SJ radar and the SD mast; aft, the cigarette deck with its 20 mm.
	var ct_z: float = d.ct_z
	var ct_len: float = d.ct_len
	var top := deck_y(d, t_of(d, ct_z)) + float(d.ct_h)
	var front := ct_z - ct_len * 0.5
	_bx(kit, BOOT, Vector3(float(d.ct_w) * 0.62, 0.06, ct_len * 0.42), Vector3(0, top + 0.01, front + ct_len * 0.3))
	_bx(kit, STEEL, Vector3(float(d.ct_w) * 0.7, 0.5, 0.08), Vector3(0, top + 0.25, front + ct_len * 0.08))
	for pz: float in [ct_z - ct_len * 0.06, ct_z + ct_len * 0.06]:
		Build.cyl(root, 0.2, 6.0, Vector3(0, top + 3.0, pz), FIN)
		Build.cyl(root, 0.12, 0.7, Vector3(0, top + 6.3, pz), STEEL)
	for side: float in [-1.0, 1.0]: # the shears' frames
		_bar(kit, FIN, Vector3(side * 0.6, top, ct_z - ct_len * 0.15), Vector3(side * 0.25, top + 5.2, ct_z), 0.14)
		_bar(kit, FIN, Vector3(side * 0.6, top, ct_z + ct_len * 0.15), Vector3(side * 0.25, top + 5.2, ct_z), 0.14)
	_bar(kit, FIN, Vector3(-0.3, top + 5.2, ct_z), Vector3(0.3, top + 5.2, ct_z), 0.16)
	var rz := ct_z + ct_len * 0.17
	Build.cyl(root, 0.08, 4.0, Vector3(0, top + 2.0, rz), STEEL) # SJ radar mast
	_bx(kit, STEEL, Vector3(1.3, 0.5, 0.12), Vector3(0, top + 4.1, rz), Basis(Vector3.RIGHT, -0.3))
	Build.cyl(root, 0.05, 5.0, Vector3(0.4, top + 2.5, ct_z - ct_len * 0.2), STEEL) # SD mast
	if d.key != "s_boat":
		var cz := ct_z + ct_len * 0.4
		var cy := deck_y(d, t_of(d, cz)) + float(d.ct_h) * 0.62
		_bx(kit, STEEL, Vector3(0.5, 0.9, 0.5), Vector3(0, cy + 0.45, cz))
		_bar(kit, BOOT, Vector3(0, cy + 1.0, cz), Vector3(0, cy + 1.35, cz - 1.6), 0.07)
		_bx(kit, STEEL, Vector3(0.8, 0.6, 0.05), Vector3(0, cy + 1.1, cz - 0.35))
	if d.key == "narwhal": # her second 6-inch gun, aft of the fin, trained fore and aft
		var az := ct_z + ct_len * 0.5 + 6.0
		var ay := deck_y(d, t_of(d, az))
		_bx(kit, STEEL, Vector3(1.4, 1.0, 1.6), Vector3(0, ay + 0.9, az))
		_bar(kit, STEEL, Vector3(0, ay + 1.3, az), Vector3(0, ay + 1.4, az + 6.0), 0.24)
	# The hull number, white on both sides of the fin.
	for side: float in [-1.0, 1.0]:
		var lb := Label3D.new()
		lb.text = NUMBERS.get(d.key, "")
		lb.font_size = 96
		lb.pixel_size = 0.011
		lb.modulate = WHITE.darkened(0.15)
		lb.outline_size = 0
		lb.double_sided = false
		var s := 0.35
		lb.position = Vector3(side * (fin_half(d, s) + 0.03), top - float(d.ct_h) * 0.42, front + s * ct_len)
		lb.rotation.y = side * PI * 0.5
		root.add_child(lb)
	# Hatches on the casing: the torpedo loading hatches fore and aft (the working one is common).
	for t: float in [0.18, 0.84]:
		var y := deck_y(d, t)
		_bx(kit, STEEL, Vector3(1.1, 0.1, 1.6), Vector3(0, y + 0.05, _z(d, t)))
		_bx(kit, BOOT, Vector3(1.2, 0.04, 0.06), Vector3(0, y + 0.07, _z(d, t) - 0.83))
	# Ready-use lockers by the fin, for the gun.
	if d.guns:
		for side: float in [-1.0, 1.0]:
			_bx(kit, STEEL, Vector3(0.6, 0.7, 1.4), Vector3(side * float(d.beam) * 0.2, deck_y(d, t_of(d, front - 1.5)) + 0.35, front - 1.5))


## A screw: a hub and `blades` blades, facing aft.
static func _screw(kit: Dictionary, at: Vector3, r: float, blades: int) -> void:
	_bx(kit, Color("#7A6A4A"), Vector3(r * 0.35, r * 0.35, r * 0.5), at)
	for k in blades:
		var a := TAU * k / blades
		var dir := Vector3(cos(a), sin(a), 0)
		_bx(kit, Color("#8A7650"), Vector3(r * 0.95, r * 0.36, 0.06), at + dir * r * 0.55,
			Basis(Vector3.BACK, a) * Basis(Vector3.RIGHT, 0.5))


## A Typhoon's gear: twenty missile hatches forward of the sail, bow planes folded low, the
## tall upper rudder, stern planes with end plates, two screws in their shrouds, the bridge
## and masts on the sail, the rescue buoys' white frames, draught marks.
static func _typhoon_gear(kit: Dictionary, d: Dictionary) -> void:
	var l: float = d.length
	var front := float(d.ct_z) - float(d.ct_len) * 0.5
	var y := float(d.deck)
	for k in 10:
		var mz := front - 5.0 - k * 5.6
		for side: float in [-1.0, 1.0]:
			var c := Vector3(side * 3.1, y + 0.08, mz)
			_bx(kit, Color("#262A2C"), Vector3(2.7, 0.16, 2.5), c)
			_bx(kit, BOOT, Vector3(2.8, 0.04, 0.08), c + Vector3(0, 0.08, -1.29))
			_bx(kit, BOOT, Vector3(0.1, 0.22, 0.6), c + Vector3(side * 1.4, 0.04, 0))
	_bx(kit, BOOT, Vector3(0.12, 0.02, 60.0), Vector3(0, y + 0.03, front - 33.0)) # the centre seam
	# Bow planes, folded into the hull low down.
	for side: float in [-1.0, 1.0]:
		var t := 0.11
		_bx(kit, RUBBER, Vector3(3.0, 0.3, 3.4), Vector3(side * (half_at(d, t, -3.0) + 1.2), -3.0, _z(d, t)))
	# The stern: planes with end plates, the tall rudder, two shrouded screws.
	var ts := 0.93
	var yc := _yc(d, ts)
	for side: float in [-1.0, 1.0]:
		var hw := half_at(d, ts, yc)
		_bx(kit, RUBBER, Vector3(6.0, 0.4, 5.0), Vector3(side * (hw + 2.8), yc, _z(d, ts)))
		_bx(kit, RUBBER, Vector3(0.3, 3.0, 4.6), Vector3(side * (hw + 5.8), yc, _z(d, ts)))
		var sx := side * 5.2
		var sz := _z(d, 0.985)
		_ring(kit, Vector3(sx, yc, sz), 2.6, 2.2, 16)
		_screw(kit, Vector3(sx, yc, sz), 2.1, 7)
	var rz := _z(d, 0.97)
	var rt := _yc(d, 0.95) + _b(d, 0.95) # the hull's top just forward of the rudder
	_bx(kit, RUBBER, Vector3(0.5, 6.0, 5.0), Vector3(0, rt + 1.5, rz)) # the tall upper rudder, out of the water
	_bx(kit, RUBBER, Vector3(0.5, 4.0, 4.0), Vector3(0, _yc(d, 0.97) - 2.5, rz))
	# On the sail: the bridge cockpit with its windows, periscopes and masts drawn down, a hatch.
	var top := y + float(d.ct_h) - 0.4
	var bz := front + 3.5
	_bx(kit, BOOT, Vector3(2.6, 0.1, 3.0), Vector3(0, top + 0.05, bz))
	for k in 5:
		for side: float in [-1.0, 1.0]:
			var s := 0.06 + k * 0.035
			_bx(kit, Color("#0A0C0E"), Vector3(0.06, 0.3, 0.45), Vector3(side * (fin_half(d, s) * 0.99), top - 0.9, front + s * float(d.ct_len)),
				Basis(Vector3.UP, side * (0.6 - k * 0.12)))
	for k in 5:
		var mz := bz + 3.5 + k * 1.6
		_bx(kit, STEEL if k < 2 else RUBBER, Vector3(0.5, 1.2 - k * 0.15, 0.5), Vector3(0, top + 0.5, mz))
	_bx(kit, Color("#262A2C"), Vector3(1.0, 0.12, 1.0), Vector3(0, top + 0.06, bz + 12.0))
	# The rescue buoys' hatches either side of the sail, each in a white frame.
	for side: float in [-1.0, 1.0]:
		var c := Vector3(side * 6.0, y + 0.04, front + 6.0)
		for e in [[Vector3(2.4, 0.03, 0.12), Vector3(0, 0, -1.2)], [Vector3(2.4, 0.03, 0.12), Vector3(0, 0, 1.2)],
				[Vector3(0.12, 0.03, 2.4), Vector3(-1.2, 0, 0)], [Vector3(0.12, 0.03, 2.4), Vector3(1.2, 0, 0)]]:
			_bx(kit, WHITE, e[0], c + e[1])
	# Escape hatches aft.
	for hz: float in [_z(d, 0.7), _z(d, 0.18)]:
		_bx(kit, Color("#262A2C"), Vector3(1.1, 0.12, 1.1), Vector3(0, deck_y(d, t_of(d, hz)) + 0.06, hz))
	# Draught marks, white, at bow and stern on both sides.
	for t: float in [0.04, 0.92]:
		for side: float in [-1.0, 1.0]:
			for k in 5:
				var my := -1.0 - k * 1.0
				_bx(kit, WHITE, Vector3(0.04, 0.12, 0.6), Vector3(side * (half_at(d, t, my) + 0.02), my, _z(d, t)))
	_bx(kit, RUBBER, Vector3(0.2, 0.2, 0.2), Vector3(0, -100, 0)) # keeps the rubber kit's mesh non-empty


## A shroud round a screw: a ring of boxes.
static func _ring(kit: Dictionary, at: Vector3, r: float, length: float, n: int) -> void:
	for k in n:
		var a := TAU * (k + 0.5) / n
		_bx(kit, RUBBER, Vector3(r * TAU / n + 0.05, 0.35, length), at + Vector3(cos(a), sin(a), 0) * r, Basis(Vector3.BACK, a + PI * 0.5))


## What every boat has: the deck hatch the crew climb out of and go below by (with its red
## dogging bar), the wrestling ring painted on the aft casing, and rungs up the side from the
## water that follow the curve of her hull.
static func _common(kit: Dictionary, d: Dictionary) -> void:
	var hz: float = d.hatch_z
	var hy := deck_y(d, t_of(d, hz))
	_bx(kit, STEEL, Vector3(1.0, 0.16, 1.0), Vector3(0, hy + 0.08, hz))
	_bx(kit, Color("#2E3236"), Vector3(0.84, 0.06, 0.84), Vector3(0, hy + 0.19, hz))
	_bx(kit, Color("#B23A2E"), Vector3(0.5, 0.06, 0.08), Vector3(0, hy + 0.24, hz))
	_bx(kit, STEEL, Vector3(0.1, 0.5, 0.1), Vector3(0, hy + 0.45, hz + 0.45)) # the cover's hinge post
	var rz: float = d.ring_z
	var ry := deck_y(d, t_of(d, rz)) + 0.03
	var rw: float = float(d.ring_edge) * 2.0
	for dz: float in [-1.0, 1.0]:
		_bx(kit, WHITE, Vector3(rw, 0.02, 0.1), Vector3(0, ry, rz + dz))
	_bx(kit, WHITE, Vector3(0.1, 0.02, 1.9), Vector3(0, ry, rz))
	var lz: float = d.ladder_z
	var lt := t_of(d, lz)
	var dy := deck_y(d, lt)
	for side: float in [-1.0, 1.0]:
		var y := -1.4
		while y < dy - 0.1:
			var x := side * (maxf(half_at(d, lt, y), deck_half(d, lt)) + 0.12)
			_bx(kit, RAIL, Vector3(0.08, 0.05, 0.55), Vector3(x, y, lz))
			for e: float in [-0.27, 0.27]:
				_bx(kit, RAIL, Vector3(0.05, 0.36, 0.05), Vector3(x, y + 0.17, lz + e))
			y += 0.35
		for e: float in [-0.3, 0.3]: # grab handles over the deck edge
			_bar(kit, RAIL, Vector3(side * (deck_half(d, lt) - 0.05), dy, lz + e), Vector3(side * (deck_half(d, lt) + 0.1), dy + 0.7, lz + e), 0.05)


## The deck gun (hidden on a missile boat, which has none).
static func _gun(root: Node3D, sub: SubClassData, d: Dictionary) -> void:
	var deck_y_gun := deck_y(d, t_of(d, d.gun_z))
	var gun := Node3D.new()
	gun.name = "Gun"
	gun.position = Vector3(0, deck_y_gun, d.gun_z)
	root.add_child(gun)
	gun.visible = d.guns
	var bore := 0.06 + sub.gun_damage * 0.12 # bigger guns, fatter barrels
	if d.guns:
		Build.lathe(root, [Vector2(0, 0), Vector2(0.75, 0), Vector2(0.55, 0.25), Vector2(0.4, 0.9), Vector2(0, 0.9)],
			gun.position, STEEL, Vector3.UP, 16) # pedestal
	Build.box(gun, Vector3(1.0, 0.6, 1.3), Vector3(0, 1.15, 0.1), STEEL, false) # carriage
	for side: float in [-1.0, 1.0]:
		Build.box(gun, Vector3(0.12, 0.7, 0.9), Vector3(side * 0.55, 1.3, 0.0), STEEL, false) # trunnion cheeks
		Build.box(gun, Vector3(0.45, 0.08, 0.35), Vector3(side * 0.95, 0.95, 0.55), ShipModels.BLACK, false) # layer's seats
	Build.box(gun, Vector3(1.3, 0.9, 0.06), Vector3(0, 1.35, -0.55), Color("#3F444A"), false) # the shield
	var barrel := Node3D.new()
	barrel.name = "Barrel"
	barrel.position = Vector3(0, 1.35, 0)
	gun.add_child(barrel)
	var bl := 3.2 + sub.gun_damage * 6.0
	Build.box(barrel, Vector3(0.5, 0.5, 0.9), Vector3(0, 0, 0.35), Color("#2E3236"), false) # breech
	Build.lathe(barrel, [Vector2(0, 0), Vector2(bore * 2.2, 0), Vector2(bore * 2.0, bl * 0.3), Vector2(bore * 1.4, bl * 0.97),
		Vector2(bore * 1.7, bl * 0.97), Vector2(bore * 1.7, bl), Vector2(0, bl)], Vector3.ZERO, Color("#2E3236"), Vector3.FORWARD, 14)
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0, -bl - 0.2)
	barrel.add_child(muzzle)
	var eye := Node3D.new()
	eye.name = "Eye"
	eye.position = Vector3(-1.0, 2.2, 3.6) # the pointer's seat, left of and behind the breech
	eye.rotation.x = deg_to_rad(-3.0)
	gun.add_child(eye)


## The Titan from outside: a white fairing round the tube, the clear-domed bow, the black frame
## and skids under her, four thrusters aft. No maker's name on her.
static func _titan(root: Node3D, sub: SubClassData) -> void:
	var white := Color("#E8E8E2")
	var black := Color("#1E2022")
	var l := sub.length
	var body := Build.cyl(root, 1.25, l * 0.62, Vector3(0, -0.15, -0.2), white, Vector3.BACK)
	body.name = "Body"
	var nose := Build.sphere(root, 1.25, Vector3(0, -0.15, -0.2 - l * 0.31), Color("#9CB6C4"))
	nose.scale = Vector3(1, 1, 0.75)
	Build.sphere(root, 0.32, Vector3(0, -0.4, -0.2 - l * 0.31 - 0.85), Color("#203440")) # the viewport
	var tail := Build.sphere(root, 1.25, Vector3(0, -0.15, -0.2 + l * 0.31), white)
	tail.scale = Vector3(1, 1, 0.6)
	Build.box(root, Vector3(2.6, 0.25, l * 0.9), Vector3(0, -1.45, 0), black, false) # the frame
	for side in [-1.0, 1.0]:
		Build.box(root, Vector3(0.18, 0.2, l), Vector3(side * 1.2, -1.6, 0), black, false) # skids
		Build.box(root, Vector3(0.12, 1.1, 0.12), Vector3(side * 1.1, -0.95, -1.5), black, false)
		Build.box(root, Vector3(0.12, 1.1, 0.12), Vector3(side * 1.1, -0.95, 1.5), black, false)
	for t: Vector3 in [Vector3(-0.9, 0.5, l * 0.45), Vector3(0.9, 0.5, l * 0.45), Vector3(-1.5, -0.3, 1.0), Vector3(1.5, -0.3, 1.0)]:
		var vertical := t.z < 2.0
		Build.cyl(root, 0.28, 0.5, t, black, Vector3.UP if vertical else Vector3.BACK)
		Build.cyl(root, 0.08, 0.6, t, Color("#5A5E62"), Vector3.UP if vertical else Vector3.BACK)
	Build.label(root, "TITAN", Vector3(1.27, 0.1, -0.4), 64, Color("#1E2022")).rotation.y = PI * 0.5
	var gun := Node3D.new() # no gun, but the views that aim one look for it
	gun.name = "Gun"
	gun.visible = false
	root.add_child(gun)
	for part in ["Eye", "Barrel"]:
		var n := Node3D.new()
		n.name = part
		gun.add_child(n)
