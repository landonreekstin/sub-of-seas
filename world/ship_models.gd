class_name ShipModels
## Builds low-poly surface ship models from primitives. Origin at the waterline,
## bow towards -Z. Sized from the class data so scale reads right in the periscope.

const HULL := Color("#4A4E55")
const HULL_LOW := Color("#7A2A22")
const UPPER := Color("#8C9096")
const LIGHT := Color("#C8C4B8")
const DECK := Color("#8B7355")
const BLACK := Color("#1E1E20")


static func build(data: ShipClassData) -> Node3D:
	var root := Node3D.new()
	root.name = data.key
	match data.kind:
		"destroyer":
			_destroyer(root, data)
		"tanker":
			_tanker(root, data)
		"carrier":
			_carrier(root, data)
		"battleship":
			_battleship(root, data)
		"cruiser":
			_cruiser(root, data)
		"kaibokan":
			_kaibokan(root, data)
		"subchaser":
			_subchaser(root, data)
		_:
			_freighter(root, data)
	return root


## The hull: a lofted mesh from bow (t = 0, z = -L/2) to stern (t = 1): a fine entry with a
## raked stem and flared bow, parallel sides amidships, a rounded stern with a transom; round
## bilges below water, a red bottom showing a little above the waterline, a tan deck with
## sheer forward and `raised` decks ([t0, t1, height]: forecastle, poop) stepping up.
## Half the beam at station t (0 the stem, 1 the stern) of a hull drawn by `_hull`.
static func hull_half(t: float, beam: float) -> float:
	var p := 1.0
	if t < 0.32:
		p = 1.0 - pow(1.0 - t / 0.32, 2.2)
	elif t > 0.82:
		p = 1.0 - 0.32 * pow((t - 0.82) / 0.18, 2.0)
	return beam * 0.5 * p


## The deck's height above the waterline at station t, with no raised decks.
static func hull_deck(t: float, freeboard: float) -> float:
	return freeboard + freeboard * 0.22 * pow(maxf(0.0, 1.0 - t / 0.18), 2.0)


## Our own boat's measurements, shared by its model and the deck the crew walk on (Deck).
## z runs bow (-) to stern (+), y up from the waterline.
static func own_dims(sub: SubClassData) -> Dictionary:
	var l := sub.length
	var d := {"length": l, "beam": clampf(l * 0.088, 6.0, 10.0), "deck": clampf(l * 0.028, 2.2, 3.2),
		"ct_z": -l * 0.06, "ct_len": l * 0.16, "ct_h": 4.2}
	d.gun_z = d.ct_z - d.ct_len * 0.5 - 6.0
	d.hatch_z = d.ct_z - d.ct_len * 0.5 - 2.6 # the deck hatch, between the gun and the fairwater
	d.ladder_z = d.ct_z + d.ct_len * 0.5 + 3.0 # rungs up the side from the water, both sides
	return d


static func _hull(root: Node3D, length: float, beam: float, freeboard: float, draft: float, color: Color,
		raised := []) -> void:
	var ts: Array[float] = []
	for i in 49:
		ts.append(i / 48.0)
	for r in raised:
		for t in [float(r[0]) - 0.004, float(r[0]) + 0.004, float(r[1]) - 0.004, float(r[1]) + 0.004]:
			if t > 0.0 and t < 1.0:
				ts.append(t)
	ts.sort()
	var deck := func(t: float) -> float:
		var y := freeboard + freeboard * 0.22 * pow(maxf(0.0, 1.0 - t / 0.18), 2.0)
		for r in raised:
			var edge := 0.004
			var up := smoothstep(float(r[0]) - edge, float(r[0]) + edge, t) if r[0] > 0.0 else 1.0
			var down := 1.0 - smoothstep(float(r[1]) - edge, float(r[1]) + edge, t) if r[1] < 1.0 else 1.0
			y += float(r[2]) * minf(up, down)
		return y
	var half := func(t: float) -> float:
		return hull_half(t, beam)
	var keel := func(t: float) -> float:
		var k := draft
		if t < 0.1:
			k *= lerpf(0.3, 1.0, smoothstep(0.0, 0.1, t))
		elif t > 0.86:
			k *= lerpf(1.0, 0.5, (t - 0.86) / 0.14)
		return k
	var split := minf(0.6, freeboard * 0.1) # the red shows this far above the water
	# A point on the starboard side at station t, height y (port mirrors x).
	var pt := func(t: float, y: float) -> Vector3:
		var hb: float = half.call(t)
		var dk: float = deck.call(t)
		var kl: float = keel.call(t)
		var w: float
		if y >= 0.0:
			w = hb * (1.0 + 0.18 * (y / dk) * maxf(0.0, 1.0 - t / 0.4))
		else:
			var full := pow(hb / (beam * 0.5), 2.0)
			var f := 1.0 - pow(clampf(-y / kl, 0.0, 1.0), lerpf(1.4, 5.0, full))
			w = hb * maxf(f, 0.06)
		var yn := (y + kl) / (dk + kl)
		var z := -length * 0.5 + t * length + length * 0.045 * (1.0 - yn) * pow(maxf(0.0, 1.0 - t / 0.3), 2.0)
		return Vector3(w, y, z)
	var rows := func(t: float, top: bool) -> Array:
		var a := []
		if top:
			var dk: float = deck.call(t)
			for k in 5:
				a.append(lerpf(dk, split, k / 4.0))
		else:
			var kl: float = keel.call(t)
			for k in 8:
				a.append(lerpf(split, -kl, pow(k / 7.0, 0.8)))
		return a
	for top in [true, false]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in ts.size() - 1:
			var ra: Array = rows.call(ts[i], top)
			var rb: Array = rows.call(ts[i + 1], top)
			for k in ra.size() - 1:
				for side in [-1.0, 1.0]:
					var m := Vector3(side, 1, 1)
					var a: Vector3 = pt.call(ts[i], ra[k]) * m
					var b: Vector3 = pt.call(ts[i + 1], rb[k]) * m
					var c: Vector3 = pt.call(ts[i + 1], rb[k + 1]) * m
					var d: Vector3 = pt.call(ts[i], ra[k + 1]) * m
					var hint := Vector3(side, -0.2 if not top else 0.0, 0)
					_tri(st, a, b, c, hint)
					_tri(st, a, c, d, hint)
			if not top: # the keel strip joining port and starboard
				var ka: Vector3 = pt.call(ts[i], ra[-1])
				var kb: Vector3 = pt.call(ts[i + 1], rb[-1])
				_tri(st, ka, kb, kb * Vector3(-1, 1, 1), Vector3.DOWN)
				_tri(st, ka, kb * Vector3(-1, 1, 1), ka * Vector3(-1, 1, 1), Vector3.DOWN)
		# The transom.
		var rt: Array = rows.call(1.0, top)
		for k in rt.size() - 1:
			var a: Vector3 = pt.call(1.0, rt[k])
			var b: Vector3 = pt.call(1.0, rt[k + 1])
			_tri(st, a, b, b * Vector3(-1, 1, 1), Vector3.BACK)
			_tri(st, a, b * Vector3(-1, 1, 1), a * Vector3(-1, 1, 1), Vector3.BACK)
		st.index()
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = Build.mat(color if top else HULL_LOW)
		root.add_child(mi)
	# The deck, edge to edge, following the sheer.
	var ds := SurfaceTool.new()
	ds.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in ts.size() - 1:
		var a: Vector3 = pt.call(ts[i], deck.call(ts[i]))
		var b: Vector3 = pt.call(ts[i + 1], deck.call(ts[i + 1]))
		a.x *= 0.97
		b.x *= 0.97
		_tri(ds, a, b, b * Vector3(-1, 1, 1), Vector3.UP)
		_tri(ds, a, b * Vector3(-1, 1, 1), a * Vector3(-1, 1, 1), Vector3.UP)
	ds.index()
	ds.generate_normals()
	var dm := MeshInstance3D.new()
	dm.mesh = ds.commit()
	dm.material_override = Build.mat(DECK)
	root.add_child(dm)
	# A dark rubbing strake along the deck edge, so the sheer line reads from afar.
	var rs := SurfaceTool.new()
	rs.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in ts.size() - 1:
		for side in [-1.0, 1.0]:
			var m := Vector3(side, 1, 1)
			var ya: float = deck.call(ts[i])
			var yb: float = deck.call(ts[i + 1])
			var a: Vector3 = pt.call(ts[i], ya) * m
			var b: Vector3 = pt.call(ts[i + 1], yb) * m
			var o := Vector3(side * 0.08, 0, 0)
			var drop := Vector3(0, -minf(0.5, freeboard * 0.08), 0)
			_tri(rs, a + o, b + o, b + o + drop, Vector3(side, 0, 0))
			_tri(rs, a + o, b + o + drop, a + o + drop, Vector3(side, 0, 0))
	rs.index()
	rs.generate_normals()
	var rm := MeshInstance3D.new()
	rm.mesh = rs.commit()
	rm.material_override = Build.mat(BLACK)
	root.add_child(rm)


## Our own boat on the surface, as the gun crew sees her from the casing: the lofted hull in
## black with a teak deck, the conning-tower fairwater with its periscope shears, and the deck
## gun forward of it. The gun is the node "Gun" (it trains about y), its barrel "Gun/Barrel"
## (recoils along +z), the muzzle "Gun/Barrel/Muzzle" and the gunlayer's eye "Gun/Eye".
static func own_boat(sub: SubClassData) -> Node3D:
	var root := Node3D.new()
	root.name = "OwnBoat"
	var d := own_dims(sub)
	var l: float = d.length
	var beam: float = d.beam
	var fb: float = d.deck
	_hull(root, l, beam, fb, 4.5, Color("#2C3034"))
	var deck_y := fb
	# The fairwater round the conning tower and bridge, a little forward of amidships.
	var ct_z: float = d.ct_z
	var ct_len: float = d.ct_len
	var ct_h: float = d.ct_h
	Build.box(root, Vector3(beam * 0.32, ct_h, ct_len), Vector3(0, deck_y + ct_h * 0.5, ct_z), Color("#33373C"))
	Build.cyl(root, beam * 0.16, ct_h, Vector3(0, deck_y + ct_h * 0.5, ct_z - ct_len * 0.5), Color("#33373C"))
	Build.box(root, Vector3(beam * 0.34, 0.15, ct_len + 0.6), Vector3(0, deck_y + ct_h, ct_z), BLACK) # bridge rail
	for z in [ct_z - ct_len * 0.1, ct_z + ct_len * 0.15]:
		Build.cyl(root, 0.22, 6.5, Vector3(0, deck_y + ct_h + 3.2, z), Color("#33373C"))
	Build.box(root, Vector3(0.12, 0.9, ct_len * 0.5), Vector3(0, deck_y + ct_h + 6.0, ct_z + 0.5), Color("#33373C"))
	# The gun on the casing forward of the fairwater.
	var gun := Node3D.new()
	gun.name = "Gun"
	gun.position = Vector3(0, deck_y, d.gun_z)
	root.add_child(gun)
	var bore := 0.06 + sub.gun_damage * 0.12 # bigger guns, fatter barrels
	Build.lathe(root, [Vector2(0, 0), Vector2(0.75, 0), Vector2(0.55, 0.25), Vector2(0.4, 0.9), Vector2(0, 0.9)],
		gun.position, Color("#3A3F44"), Vector3.UP, 16) # pedestal
	Build.box(gun, Vector3(1.0, 0.6, 1.3), Vector3(0, 1.15, 0.1), Color("#3A3F44"), false) # carriage
	for side in [-1.0, 1.0]:
		Build.box(gun, Vector3(0.12, 0.7, 0.9), Vector3(side * 0.55, 1.3, 0.0), Color("#3A3F44"), false) # trunnion cheeks
		Build.box(gun, Vector3(0.45, 0.08, 0.35), Vector3(side * 0.95, 0.95, 0.55), BLACK, false) # layer's seats
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
	# Ready-use ammunition lockers by the fairwater.
	for side in [-1.0, 1.0]:
		Build.box(root, Vector3(0.6, 0.7, 1.4), Vector3(side * beam * 0.22, deck_y + 0.35, ct_z - ct_len * 0.5 - 1.5), Color("#3A3F44"))
	# The deck hatch the crew climb out of, and rungs up the side from the water.
	var hz: float = d.hatch_z
	Build.cyl(root, 0.48, 0.16, Vector3(0, deck_y + 0.08, hz), Color("#3A3F44"))
	Build.cyl(root, 0.42, 0.06, Vector3(0, deck_y + 0.19, hz), Color("#2E3236"))
	Build.box(root, Vector3(0.5, 0.05, 0.06), Vector3(0, deck_y + 0.24, hz), Color("#B23A2E"), false) # dogging bar
	var lt: float = (float(d.ladder_z) + l * 0.5) / l
	for side in [-1.0, 1.0]:
		var x: float = side * (hull_half(lt, beam) + 0.12)
		for rail in [-0.25, 0.25]:
			Build.box(root, Vector3(0.06, deck_y + 1.6, 0.06), Vector3(x, deck_y * 0.5 - 0.8 + 0.1, d.ladder_z + rail), Color("#8A8F86"), false)
		for k in int((deck_y + 1.4) / 0.35):
			Build.box(root, Vector3(0.06, 0.05, 0.5), Vector3(x, -1.4 + k * 0.35, d.ladder_z), Color("#8A8F86"), false)
	return root


## A triangle facing roughly `hint` (Godot's front faces wind clockwise).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, hint: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		return
	if n.dot(hint) > 0.0:
		var t := b
		b = c
		c = t
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


static func _freighter(root: Node3D, d: ShipClassData) -> void:
	var L := d.length
	var B := d.beam
	# Forecastle and poop raised decks, bridge island amidships-aft.
	_hull(root, L, B, 6.0, 7.0, HULL, [[0.0, 0.24, 2.45], [0.87, 1.0, 2.45]])
	_house(root, Vector3(B * 0.8, 4.0, L * 0.12), Vector3(0, 8.0, L * 0.1), LIGHT, false)
	_house(root, Vector3(B * 0.6, 3.0, L * 0.08), Vector3(0, 11.5, L * 0.08))
	Build.box(root, Vector3(B * 0.9, 0.3, 3.0), Vector3(0, 12.6, L * 0.08 - L * 0.04 + 1.5), LIGHT, false) # bridge wings
	var f := _funnel(root, 2.2, 8.0, Vector3(0, 9.5, L * 0.2), 4.0)
	Build.cyl(f, 2.25, 1.0, Vector3(0, 6.0, 0), Color("#C8A04A")) # the company band
	for side in [-1.0, 1.0]:
		_boat(root, 6.0, Vector3(side * B * 0.32, 10.4, L * 0.15))
		Build.cyl(root, 0.4, 2.5, Vector3(side * B * 0.2, 7.2, L * 0.24), Color("#C8C4B8")) # ventilators
	# Masts with cargo booms.
	for z in [-L * 0.22, L * 0.33]:
		_mast(root, 20.0, Vector3(0, 6.0, z), 0.4)
		Build.box(root, Vector3(2.2, 2.0, 2.2), Vector3(0, 7.0, z), UPPER, false) # mast house
		for side in [-1.0, 1.0]:
			var boom := Build.cyl(root, 0.18, 12.0, Vector3(side * 1.2, 11.0, z + (5.0 if z < 0.0 else -5.0)), UPPER)
			boom.rotation.x = deg_to_rad(60.0 if z < 0.0 else -60.0)
	# Hatch covers, tarpaulined.
	for z in [-L * 0.12, L * 0.0, L * 0.28]:
		Build.box(root, Vector3(B * 0.5, 1.0, 8.0), Vector3(0, 6.5, z), Color("#5A6048"), false)
	_ports(root, L, B, 4.4, 0.3, 0.6, 5.0)


static func _destroyer(root: Node3D, d: ShipClassData) -> void:
	var L := d.length
	var B := d.beam
	_hull(root, L, B, 4.5, 3.8, HULL, [[0.0, 0.4, 2.2]])
	_house(root, Vector3(B * 0.55, 5.0, 8.0), Vector3(0, 8.0, -L * 0.2), UPPER) # bridge
	Build.box(root, Vector3(B * 0.65, 1.0, 4.0), Vector3(0, 11.0, -L * 0.21), BLACK, false) # director
	_mast(root, 16.0, Vector3(0, 6.5, -L * 0.15), 0.35)
	for z in [-L * 0.05, L * 0.08]:
		_funnel(root, 1.4, 7.0, Vector3(0, 5.0, z), 8.0)
	_turret(root, 2.4, Vector3(0, 8.0, -L * 0.36), 2)
	_turret(root, 2.4, Vector3(0, 6.0, L * 0.27), 2, true)
	_turret(root, 2.4, Vector3(0, 7.0, L * 0.37), 2, true)
	for z in [L * 0.0, L * 0.15]: # quadruple torpedo mounts
		Build.cyl(root, 1.2, 0.5, Vector3(0, 4.8, z), Color("#5A5F66"))
		for k in 4:
			Build.cyl(root, 0.28, 6.0, Vector3(-0.9 + k * 0.6, 5.4, z), Color("#5A5F66"), Vector3.BACK)
	for side in [-1.0, 1.0]:
		_boat(root, 5.0, Vector3(side * B * 0.32, 6.0, -L * 0.1))
	Build.box(root, Vector3(B * 0.8, 0.8, 2.0), Vector3(0, 5.0, L * 0.47), Color("#2B2B2B"), false) # depth-charge racks
	for side in [-1.0, 1.0]:
		for k in 3:
			Build.cyl(root, 0.35, 0.9, Vector3(side * B * 0.3, 5.0, L * 0.4 - k * 1.2), Color("#2B2B2B")) # charges ready


## A gun turret with `barrels` barrels pointing along -Z (forward) or +Z when `aft`: a round
## barbette, a bevelled gunhouse with a sloped face, tapered barrels with muzzle rings.
static func _turret(root: Node3D, size: float, pos: Vector3, barrels: int, aft := false) -> void:
	Build.cyl(root, size * 0.62, size * 0.5, pos + Vector3(0, -size * 0.35, 0), UPPER)
	var t := Node3D.new()
	t.position = pos
	if aft:
		t.rotation.y = PI
	root.add_child(t)
	Build.box(t, Vector3(size * 1.4, size * 0.7, size * 1.3), Vector3(0, 0, size * 0.15), UPPER, false)
	var face := Build.box(t, Vector3(size * 1.3, size * 0.55, size * 0.5), Vector3(0, -size * 0.04, -size * 0.55), UPPER, false)
	face.rotation.x = deg_to_rad(-25.0)
	Build.box(t, Vector3(size * 0.25, size * 0.12, size * 0.5), Vector3(size * 0.45, size * 0.4, size * 0.35), LIGHT, false) # rangefinder hood
	for i in barrels:
		var x := (i - (barrels - 1) * 0.5) * size * 0.4
		var r := size * 0.09
		var l := size * 2.2
		Build.lathe(t, [Vector2(0, 0), Vector2(r * 1.25, 0), Vector2(r * 1.1, l * 0.3), Vector2(r * 0.8, l * 0.95),
				Vector2(r * 1.05, l * 0.95), Vector2(r * 1.05, l), Vector2(0, l)],
				Vector3(x, size * 0.05, -size * 0.6), BLACK, Vector3.FORWARD, 10)


## A funnel: tapering a little, with a lip and a black cap; raked aft by `rake` degrees.
static func _funnel(root: Node3D, radius: float, height: float, pos: Vector3, rake := 8.0, cap := BLACK) -> Node3D:
	var f := Node3D.new()
	f.position = pos
	f.rotation.x = deg_to_rad(rake)
	root.add_child(f)
	Build.lathe(f, [Vector2(0, 0), Vector2(radius * 1.08, 0), Vector2(radius, height * 0.86)], Vector3.ZERO, UPPER)
	Build.lathe(f, [Vector2(radius, 0), Vector2(radius * 1.04, 0), Vector2(radius * 1.04, height * 0.14 - 0.25),
			Vector2(radius * 1.1, height * 0.14 - 0.15), Vector2(radius * 1.1, height * 0.14), Vector2(radius * 0.85, height * 0.14)],
			Vector3(0, height * 0.86, 0), cap)
	Build.lathe(f, [Vector2(0, 0), Vector2(radius * 0.86, 0)], Vector3(0, height * 0.97, 0), Color("#151517"), Vector3.UP)
	return f


## A deckhouse with a dark band of windows round its top and a roof that overhangs a little.
static func _house(root: Node3D, size: Vector3, pos: Vector3, color := LIGHT, windows := true) -> void:
	Build.box(root, size, pos, color, false)
	if windows:
		Build.box(root, Vector3(size.x * 1.01, minf(1.0, size.y * 0.22), size.z * 1.01), pos + Vector3(0, size.y * 0.22, 0), Color("#24282C"), false)
	Build.box(root, Vector3(size.x * 1.08, minf(0.35, size.y * 0.08), size.z * 1.08), pos + Vector3(0, size.y * 0.5, 0), color, false)


## A tapering pole mast with a yard across it and a small top.
static func _mast(root: Node3D, height: float, pos: Vector3, radius := 0.35) -> void:
	Build.lathe(root, [Vector2(0, 0), Vector2(radius, 0), Vector2(radius * 0.45, height), Vector2(0, height)], pos, UPPER, Vector3.UP, 10)
	Build.cyl(root, radius * 0.35, height * 0.45, pos + Vector3(0, height * 0.72, 0), UPPER, Vector3.RIGHT)
	Build.cyl(root, radius * 2.2, radius * 0.6, pos + Vector3(0, height * 0.6, 0), BLACK)


## A white ship's boat on its chocks, bow forward.
static func _boat(root: Node3D, length: float, pos: Vector3) -> void:
	var b := Build.sphere(root, 0.5, pos, Color("#E8E4D8"))
	b.scale = Vector3(length * 0.32, length * 0.22, length)
	Build.box(root, Vector3(length * 0.26, length * 0.04, length * 0.75), pos + Vector3(0, length * 0.1, 0), Color("#8B7355"), false)


## A row of dark portholes down both sides amidships, `y` above the water.
static func _ports(root: Node3D, length: float, beam: float, y: float, t0 := 0.42, t1 := 0.8, spacing := 4.0) -> void:
	var n := int((t1 - t0) * length / spacing)
	for i in n:
		var z := -length * 0.5 + lerpf(t0, t1, (i + 0.5) / n) * length
		for side in [-1.0, 1.0]:
			Build.cyl(root, 0.22, 0.1, Vector3(side * beam * 0.5, y, z), Color("#1A1C1E"), Vector3.RIGHT)


static func _tanker(root: Node3D, d: ShipClassData) -> void:
	var L := d.length
	var B := d.beam
	_hull(root, L, B, 4.5, 8.0, HULL, [[0.0, 0.13, 2.45], [0.82, 1.0, 1.5]])
	_house(root, Vector3(B * 0.7, 6.0, L * 0.07), Vector3(0, 7.5, -L * 0.15)) # midships bridge
	_house(root, Vector3(B * 0.9, 5.0, L * 0.16), Vector3(0, 8.5, L * 0.38), LIGHT, false) # aft house
	_house(root, Vector3(B * 0.6, 2.5, L * 0.08), Vector3(0, 12.2, L * 0.36))
	_funnel(root, 2.0, 8.0, Vector3(0, 11.0, L * 0.42), 6.0)
	Build.box(root, Vector3(1.2, 0.8, L * 0.6), Vector3(0, 5.6, L * 0.05), Color("#5A5F66"), false) # pipe catwalk
	for k in 10: # tank hatches along the well deck
		Build.cyl(root, 0.9, 0.5, Vector3(B * 0.25 * (1.0 if k % 2 == 0 else -1.0), 4.7, -L * 0.25 + k * L * 0.055), Color("#5A5F66"))
	for z in [-L * 0.32, L * 0.25]:
		_mast(root, 14.0, Vector3(0, 4.5, z), 0.3)
	for side in [-1.0, 1.0]:
		_boat(root, 6.0, Vector3(side * B * 0.38, 11.5, L * 0.32))
	_ports(root, L, B, 3.0, 0.82, 0.97, 3.5)


static func _carrier(root: Node3D, d: ShipClassData) -> void:
	var L := d.length
	var B := d.beam
	_hull(root, L * 0.95, B, 8.0, 8.8, HULL)
	# Flight deck overhangs the hull fore and aft; open hangar sides below it.
	Build.box(root, Vector3(B * 0.85, 6.0, L * 0.7), Vector3(0, 11.0, 0), Color("#5A5F66"), false)
	for k in 9: # hangar openings
		Build.box(root, Vector3(B * 0.86, 2.6, L * 0.05), Vector3(0, 11.5, -L * 0.3 + k * L * 0.075), Color("#2A2D31"), false)
	Build.box(root, Vector3(B * 1.0, 0.6, L), Vector3(0, 14.3, 0), DECK, false)
	Build.box(root, Vector3(0.6, 0.62, L * 0.95), Vector3(0, 14.32, 0), LIGHT, false) # centreline stripe
	Build.box(root, Vector3(B * 0.98, 0.62, 1.0), Vector3(0, 14.32, L * 0.42), Color("#E8E4D8"), false)
	Build.box(root, Vector3(B * 0.98, 0.62, 1.0), Vector3(0, 14.32, -L * 0.42), Color("#E8E4D8"), false)
	for k in 3: # elevators
		Build.box(root, Vector3(12.0, 0.63, 12.0), Vector3(0, 14.31, -L * 0.3 + k * L * 0.3), Color("#7A6448"), false)
	# Galleries of AA guns along the deck edge.
	for side in [-1.0, 1.0]:
		for k in 6:
			Build.box(root, Vector3(3.0, 0.4, 6.0), Vector3(side * (B * 0.5 + 1.0), 13.2, -L * 0.35 + k * L * 0.14), UPPER, false)
	# Starboard island with its funnel.
	_house(root, Vector3(3.0, 7.0, 14.0), Vector3(B * 0.5 + 1.0, 18.0, -L * 0.12), UPPER)
	Build.box(root, Vector3(3.5, 1.0, 6.0), Vector3(B * 0.5 + 1.0, 22.0, -L * 0.14), BLACK, false)
	_mast(root, 10.0, Vector3(B * 0.5 + 1.0, 21.5, -L * 0.1), 0.3)
	var f := Build.lathe(root, [Vector2(0, 0), Vector2(2.2, 0), Vector2(2.0, 9.0), Vector2(0, 9.0)], Vector3(B * 0.5 + 1.5, 10.5, -L * 0.02), UPPER)
	f.rotation.z = deg_to_rad(-120.0) # trunked out and down to starboard


static func _battleship(root: Node3D, d: ShipClassData) -> void:
	var L := d.length
	var B := d.beam
	_hull(root, L, B, 7.0, 8.5, HULL, [[0.0, 0.425, 2.45]])
	# Pagoda foremast: stacked platforms, each with its windows and overhang.
	for i in 6:
		var w := B * (0.55 - i * 0.06)
		_house(root, Vector3(w, 3.6, 10.0 - i * 0.9), Vector3(0, 11.3 + i * 3.6, -L * 0.1), UPPER if i % 2 == 0 else LIGHT, i >= 3)
	Build.box(root, Vector3(B * 0.35, 1.2, 5.0), Vector3(0, 33.5, -L * 0.1), BLACK, false)
	_mast(root, 8.0, Vector3(0, 34.0, -L * 0.1), 0.35)
	_funnel(root, 2.8, 9.0, Vector3(0, 9.5, L * 0.02), 5.0)
	_funnel(root, 2.6, 8.0, Vector3(0, 9.5, L * 0.12), 5.0)
	_mast(root, 18.0, Vector3(0, 9.5, L * 0.22), 0.5) # mainmast
	_turret(root, 6.0, Vector3(0, 12.3, -L * 0.36), 2)
	_turret(root, 6.0, Vector3(0, 13.8, -L * 0.25), 2)
	_turret(root, 6.0, Vector3(0, 9.3, L * 0.3), 2, true)
	_turret(root, 6.0, Vector3(0, 9.3, L * 0.4), 2, true)
	for side in [-1.0, 1.0]: # secondary casemates
		for k in 4:
			Build.cyl(root, 0.25, 5.0, Vector3(side * B * 0.47, 8.0, -L * 0.15 + k * 6.0), BLACK, Vector3.BACK)
		_boat(root, 8.0, Vector3(side * B * 0.3, 10.5, L * 0.08))
	_ports(root, L, B, 4.5, 0.3, 0.85, 4.0)


static func _cruiser(root: Node3D, d: ShipClassData) -> void:
	var L := d.length
	var B := d.beam
	_hull(root, L, B, 6.0, 6.2, HULL, [[0.0, 0.48, 2.2]])
	# The Takao's huge bridge block.
	_house(root, Vector3(B * 0.6, 9.0, 14.0), Vector3(0, 12.5, -L * 0.1), UPPER, false)
	_house(root, Vector3(B * 0.45, 4.0, 9.0), Vector3(0, 19.0, -L * 0.1))
	Build.box(root, Vector3(B * 0.5, 1.0, 5.0), Vector3(0, 21.7, -L * 0.1), BLACK, false)
	_mast(root, 12.0, Vector3(0, 21.0, -L * 0.07), 0.35)
	_funnel(root, 2.4, 10.0, Vector3(0, 8.0, L * 0.0), 25.0) # the trunked, raked funnel
	_mast(root, 14.0, Vector3(0, 8.0, L * 0.15), 0.35)
	for i in 3:
		_turret(root, 4.0, Vector3(0, 10.4 + (1.2 if i == 1 else 0.0), -L * 0.42 + i * 11.0), 2)
	for i in 2:
		_turret(root, 4.0, Vector3(0, 8.4 + (1.0 if i == 0 else 0.0), L * 0.3 + i * 10.0), 2, true)
	for side in [-1.0, 1.0]:
		_boat(root, 6.0, Vector3(side * B * 0.32, 9.0, L * 0.08))
		for k in 2: # torpedo tubes on the upper deck
			Build.cyl(root, 0.3, 7.0, Vector3(side * B * 0.38, 7.0, L * 0.12 + k * 0.7), Color("#5A5F66"), Vector3.BACK)
	_ports(root, L, B, 3.8, 0.35, 0.85, 4.0)


static func _kaibokan(root: Node3D, d: ShipClassData) -> void:
	var L := d.length
	var B := d.beam
	_hull(root, L, B, 3.5, 3.0, HULL, [[0.0, 0.3, 1.2]])
	_house(root, Vector3(B * 0.6, 3.5, 7.0), Vector3(0, 6.4, -L * 0.15), UPPER)
	Build.box(root, Vector3(B * 0.5, 1.0, 3.0), Vector3(0, 8.6, -L * 0.16), BLACK, false)
	_funnel(root, 1.2, 5.0, Vector3(0, 3.5, L * 0.05), 5.0)
	_mast(root, 10.0, Vector3(0, 4.6, -L * 0.08), 0.25)
	_turret(root, 2.0, Vector3(0, 5.8, -L * 0.36), 1)
	_turret(root, 2.0, Vector3(0, 4.6, L * 0.25), 2, true)
	for side in [-1.0, 1.0]:
		Build.cyl(root, 0.35, 1.2, Vector3(side * B * 0.38, 4.1, L * 0.35), BLACK) # K-guns
		_boat(root, 4.0, Vector3(side * B * 0.3, 4.6, L * 0.12))
	Build.box(root, Vector3(B * 0.8, 0.8, 3.0), Vector3(0, 4.0, L * 0.46), Color("#2B2B2B"), false)


static func _subchaser(root: Node3D, d: ShipClassData) -> void:
	var L := d.length
	var B := d.beam
	_hull(root, L, B, 2.6, 2.0, HULL)
	_house(root, Vector3(B * 0.6, 2.4, 6.0), Vector3(0, 3.8, -L * 0.12), UPPER)
	Build.box(root, Vector3(B * 0.5, 0.7, 2.5), Vector3(0, 5.3, -L * 0.13), BLACK, false)
	_mast(root, 8.0, Vector3(0, 3.0, -L * 0.05), 0.18)
	_funnel(root, 0.7, 2.5, Vector3(0, 3.0, L * 0.08), 6.0)
	_turret(root, 1.4, Vector3(0, 3.6, -L * 0.34), 1)
	Build.box(root, Vector3(B * 0.7, 0.6, 2.0), Vector3(0, 2.9, L * 0.44), Color("#2B2B2B"), false)


## A low-wing carrier plane, nose to -Z: green-grey with red roundels.
static func plane() -> Node3D:
	var n := Node3D.new()
	var green := Color("#5C6A4A")
	Build.cyl(n, 0.6, 10.0, Vector3.ZERO, green, Vector3.BACK)
	Build.box(n, Vector3(14.0, 0.25, 2.4), Vector3(0, -0.3, -0.5), green, false)
	Build.box(n, Vector3(5.0, 0.2, 1.4), Vector3(0, 0.2, 4.4), green, false)
	Build.box(n, Vector3(0.2, 1.8, 1.4), Vector3(0, 1.0, 4.4), green, false)
	Build.cyl(n, 0.7, 0.4, Vector3(0, 0, -5.1), Color("#2B2B2B"), Vector3.BACK)
	for x in [-5.0, 5.0]:
		Build.cyl(n, 0.6, 0.05, Vector3(x, -0.15, -0.5), Color("#B23A2E"))
	return n
