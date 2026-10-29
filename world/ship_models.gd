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


static func _hull(root: Node3D, length: float, beam: float, freeboard: float, draft: float, color: Color) -> void:
	var body := length * 0.78
	var mid_z := length * 0.5 - body * 0.5 # stern flush with +L/2
	var h := freeboard + draft
	Build.box(root, Vector3(beam, h, body), Vector3(0, (freeboard - draft) * 0.5, mid_z), color, false)
	Build.box(root, Vector3(beam * 1.01, draft, body * 1.0), Vector3(0, -draft * 0.5, mid_z), HULL_LOW, false)
	# Pointed bow: a prism with its apex towards -Z.
	var bow := MeshInstance3D.new()
	var pm := PrismMesh.new()
	var bow_len := length - body
	pm.size = Vector3(beam, bow_len, h)
	bow.mesh = pm
	bow.material_override = Build.mat(color)
	bow.rotation.x = -PI / 2.0
	bow.position = Vector3(0, (freeboard - draft) * 0.5, -length * 0.5 + bow_len * 0.5)
	root.add_child(bow)
	Build.box(root, Vector3(beam * 0.96, 0.15, body), Vector3(0, freeboard, mid_z), DECK, false)


static func _freighter(root: Node3D, d: ShipClassData) -> void:
	var L := d.length
	var B := d.beam
	_hull(root, L, B, 6.0, 7.0, HULL)
	# Forecastle and poop raised decks, bridge island amidships-aft.
	Build.box(root, Vector3(B * 0.95, 2.5, L * 0.12), Vector3(0, 7.2, -L * 0.3), HULL, false)
	Build.box(root, Vector3(B * 0.95, 2.5, L * 0.12), Vector3(0, 7.2, L * 0.43), HULL, false)
	Build.box(root, Vector3(B * 0.8, 4.0, L * 0.12), Vector3(0, 8.0, L * 0.1), LIGHT, false)
	Build.box(root, Vector3(B * 0.6, 3.0, L * 0.08), Vector3(0, 11.5, L * 0.08), LIGHT, false)
	Build.box(root, Vector3(B * 0.7, 0.6, L * 0.1), Vector3(0, 13.2, L * 0.08), BLACK, false)
	Build.cyl(root, 2.2, 8.0, Vector3(0, 13.0, L * 0.2), BLACK)
	Build.cyl(root, 2.25, 1.2, Vector3(0, 15.0, L * 0.2), Color("#C8A04A"))
	# Masts and cargo booms.
	for z in [-L * 0.22, L * 0.33]:
		Build.cyl(root, 0.35, 20.0, Vector3(0, 16.0, z), UPPER)
		var boom := Build.cyl(root, 0.2, 12.0, Vector3(0, 10.5, z + 5.0), UPPER)
		boom.rotation.x = deg_to_rad(60.0)
	# Hatch covers.
	for z in [-L * 0.12, L * 0.0, L * 0.28]:
		Build.box(root, Vector3(B * 0.5, 0.9, 8.0), Vector3(0, 6.5, z), DECK, false)


static func _destroyer(root: Node3D, d: ShipClassData) -> void:
	var L := d.length
	var B := d.beam
	_hull(root, L, B, 4.5, 3.8, HULL)
	Build.box(root, Vector3(B * 0.9, 2.2, L * 0.3), Vector3(0, 5.6, -L * 0.25), HULL, false) # forecastle
	Build.box(root, Vector3(B * 0.55, 5.0, 8.0), Vector3(0, 8.0, -L * 0.2), UPPER, false) # bridge
	Build.box(root, Vector3(B * 0.65, 1.0, 4.0), Vector3(0, 10.8, -L * 0.21), BLACK, false)
	Build.cyl(root, 0.3, 14.0, Vector3(0, 14.0, -L * 0.15), UPPER)
	for z in [-L * 0.05, L * 0.08]:
		var f := Build.cyl(root, 1.4, 7.0, Vector3(0, 8.5, z), UPPER)
		f.rotation.x = deg_to_rad(8.0)
		Build.cyl(root, 1.45, 0.8, Vector3(0, 11.8, z + 0.5), BLACK)
	for z in [-L * 0.38, -L * 0.28, L * 0.25, L * 0.36]:
		Build.box(root, Vector3(3.2, 2.0, 4.0), Vector3(0, 6.0 if z < 0.0 else 5.5, z), UPPER, false) # gun houses
		Build.cyl(root, 0.15, 5.0, Vector3(-0.6, 6.2, z - 4.0), BLACK, Vector3.BACK)
		Build.cyl(root, 0.15, 5.0, Vector3(0.6, 6.2, z - 4.0), BLACK, Vector3.BACK)
	for z in [L * 0.0, L * 0.15]:
		Build.box(root, Vector3(2.4, 1.0, 5.0), Vector3(0, 5.2, z), Color("#5A5F66"), false) # torpedo mounts
	Build.box(root, Vector3(B * 0.8, 0.8, 2.0), Vector3(0, 5.0, L * 0.47), Color("#2B2B2B"), false) # depth-charge racks


## A gun turret with `barrels` barrels pointing along -Z (forward) or +Z when `aft`.
static func _turret(root: Node3D, size: float, pos: Vector3, barrels: int, aft := false) -> void:
	Build.box(root, Vector3(size * 1.4, size * 0.7, size * 1.6), pos, UPPER, false)
	var dir := 1.0 if aft else -1.0
	for i in barrels:
		var x := (i - (barrels - 1) * 0.5) * size * 0.4
		Build.cyl(root, size * 0.09, size * 2.2, pos + Vector3(x, size * 0.1, dir * size * 1.7), BLACK, Vector3.BACK)


static func _funnel(root: Node3D, radius: float, height: float, pos: Vector3, rake := 8.0) -> void:
	var f := Build.cyl(root, radius, height, pos + Vector3(0, height * 0.5, 0), UPPER)
	f.rotation.x = deg_to_rad(rake)
	Build.cyl(root, radius * 1.03, height * 0.12, pos + Vector3(0, height * 0.95, height * sin(deg_to_rad(rake)) * 0.5), BLACK)


static func _tanker(root: Node3D, d: ShipClassData) -> void:
	var L := d.length
	var B := d.beam
	_hull(root, L, B, 4.5, 8.0, HULL)
	Build.box(root, Vector3(B * 0.9, 2.5, L * 0.1), Vector3(0, 5.7, -L * 0.42), HULL, false) # forecastle
	Build.box(root, Vector3(B * 0.7, 6.0, L * 0.07), Vector3(0, 7.5, -L * 0.15), LIGHT, false) # midships bridge
	Build.box(root, Vector3(B * 0.9, 5.0, L * 0.16), Vector3(0, 7.0, L * 0.38), LIGHT, false) # aft house
	_funnel(root, 2.0, 8.0, Vector3(0, 9.5, L * 0.4))
	Build.box(root, Vector3(1.2, 0.8, L * 0.6), Vector3(0, 5.2, L * 0.05), Color("#5A5F66"), false) # pipe catwalk
	for z in [-L * 0.32, L * 0.25]:
		Build.cyl(root, 0.3, 14.0, Vector3(0, 11.0, z), UPPER)


static func _carrier(root: Node3D, d: ShipClassData) -> void:
	var L := d.length
	var B := d.beam
	_hull(root, L * 0.95, B, 8.0, 8.8, HULL)
	# Flight deck overhangs the hull fore and aft; open hangar sides below it.
	Build.box(root, Vector3(B * 0.85, 6.0, L * 0.7), Vector3(0, 11.0, 0), Color("#5A5F66"), false)
	Build.box(root, Vector3(B * 1.0, 0.6, L), Vector3(0, 14.3, 0), DECK, false)
	Build.box(root, Vector3(0.6, 0.62, L * 0.95), Vector3(0, 14.32, 0), LIGHT, false) # centreline stripe
	# Starboard island with its funnel.
	Build.box(root, Vector3(3.0, 7.0, 14.0), Vector3(B * 0.5 + 1.0, 18.0, -L * 0.12), UPPER, false)
	Build.box(root, Vector3(3.5, 1.0, 6.0), Vector3(B * 0.5 + 1.0, 21.8, -L * 0.14), BLACK, false)
	var f := Build.cyl(root, 2.0, 9.0, Vector3(B * 0.5 + 3.0, 10.0, -L * 0.02), UPPER)
	f.rotation.z = deg_to_rad(-60.0) # trunked out and down to starboard


static func _battleship(root: Node3D, d: ShipClassData) -> void:
	var L := d.length
	var B := d.beam
	_hull(root, L, B, 7.0, 8.5, HULL)
	Build.box(root, Vector3(B * 0.9, 2.5, L * 0.35), Vector3(0, 8.2, -L * 0.25), HULL, false)
	# Pagoda foremast: stacked platforms.
	for i in 6:
		var w := B * (0.55 - i * 0.06)
		Build.box(root, Vector3(w, 3.6, 10.0 - i * 0.9), Vector3(0, 11.0 + i * 3.6, -L * 0.1), UPPER if i % 2 == 0 else LIGHT, false)
	Build.box(root, Vector3(B * 0.35, 1.2, 5.0), Vector3(0, 33.0, -L * 0.1), BLACK, false)
	_funnel(root, 2.8, 9.0, Vector3(0, 9.0, L * 0.02), 5.0)
	_funnel(root, 2.6, 8.0, Vector3(0, 9.0, L * 0.12), 5.0)
	Build.cyl(root, 0.5, 18.0, Vector3(0, 18.0, L * 0.22), UPPER) # mainmast
	for z in [-L * 0.36, -L * 0.25]:
		_turret(root, 6.0, Vector3(0, 10.5 if z > -L * 0.3 else 9.8, z), 2)
	for z in [L * 0.3, L * 0.4]:
		_turret(root, 6.0, Vector3(0, 9.5, z), 2, true)


static func _cruiser(root: Node3D, d: ShipClassData) -> void:
	var L := d.length
	var B := d.beam
	_hull(root, L, B, 6.0, 6.2, HULL)
	Build.box(root, Vector3(B * 0.9, 2.2, L * 0.4), Vector3(0, 7.1, -L * 0.22), HULL, false)
	# The Takao's huge bridge block.
	Build.box(root, Vector3(B * 0.6, 9.0, 14.0), Vector3(0, 12.5, -L * 0.1), UPPER, false)
	Build.box(root, Vector3(B * 0.45, 4.0, 9.0), Vector3(0, 19.0, -L * 0.1), LIGHT, false)
	Build.box(root, Vector3(B * 0.5, 1.0, 5.0), Vector3(0, 21.5, -L * 0.1), BLACK, false)
	var f := Build.cyl(root, 2.4, 10.0, Vector3(0, 12.0, L * 0.02), UPPER)
	f.rotation.x = deg_to_rad(25.0) # the trunked, raked funnel
	for i in 3:
		_turret(root, 4.0, Vector3(0, 9.6 + (1.0 if i == 1 else 0.0), -L * 0.42 + i * 11.0), 2)
	for i in 2:
		_turret(root, 4.0, Vector3(0, 7.6 + (1.0 if i == 0 else 0.0), L * 0.3 + i * 10.0), 2, true)


static func _kaibokan(root: Node3D, d: ShipClassData) -> void:
	var L := d.length
	var B := d.beam
	_hull(root, L, B, 3.5, 3.0, HULL)
	Build.box(root, Vector3(B * 0.6, 3.5, 7.0), Vector3(0, 5.2, -L * 0.15), UPPER, false)
	Build.box(root, Vector3(B * 0.5, 1.0, 3.0), Vector3(0, 7.3, -L * 0.16), BLACK, false)
	_funnel(root, 1.2, 5.0, Vector3(0, 3.5, L * 0.05), 5.0)
	Build.cyl(root, 0.25, 10.0, Vector3(0, 8.0, -L * 0.08), UPPER)
	_turret(root, 2.0, Vector3(0, 4.6, -L * 0.36), 1)
	_turret(root, 2.0, Vector3(0, 4.6, L * 0.25), 2, true)
	for side in [-1.0, 1.0]:
		Build.cyl(root, 0.35, 1.2, Vector3(side * B * 0.38, 4.1, L * 0.35), BLACK) # K-guns
	Build.box(root, Vector3(B * 0.8, 0.8, 3.0), Vector3(0, 4.0, L * 0.46), Color("#2B2B2B"), false)


static func _subchaser(root: Node3D, d: ShipClassData) -> void:
	var L := d.length
	var B := d.beam
	_hull(root, L, B, 2.6, 2.0, HULL)
	Build.box(root, Vector3(B * 0.6, 2.4, 6.0), Vector3(0, 3.8, -L * 0.12), UPPER, false)
	Build.box(root, Vector3(B * 0.5, 0.7, 2.5), Vector3(0, 5.3, -L * 0.13), BLACK, false)
	Build.cyl(root, 0.18, 8.0, Vector3(0, 7.0, -L * 0.05), UPPER)
	_turret(root, 1.4, Vector3(0, 3.2, -L * 0.34), 1)
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
