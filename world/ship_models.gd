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
