class_name TyphoonLayout
extends RefCounted
## The Typhoon (Project 941): five pressure hulls. Two long main hulls side by side (x = ±6), a
## small command hull above and between them, a torpedo hull forward and a steering hull aft;
## the missile tubes stand between the main hulls, with a passage aft of them. 175 m stem to
## stern, 19 compartments, joined by doors along each hull and three cross passages. Public
## sources give the hulls and sections; the rooms inside them are our best fit (docs/notes.md).
## Each compartment is built on its own root so what you can't see isn't drawn
## (SubInterior._cull_rooms), which is what keeps a boat this size from lagging.

const HULL_X := 6.0
const UPPER_Y := 2.86 ## the command hull's floor, clear above the passage's ceiling (2.8): level with it, they flicker
const HATCH_Z := -11.0 ## the ladder from the passage up into the command hull
const SOVIET_SHIRT := Color("#27354F")
const BAND_ROOM := "rec"
const RED_PIPE := Color("#B23A2E")

## type, name, x, y, z0, z1 and its sign in Russian.
const ROOMS := [
	["sonar", "sonar compartment", 0.0, 0.0, -105.0, -97.0, "ГИДРОАКУСТИКА"],
	["fwd_torpedo", "torpedo compartment", 0.0, 0.0, -97.0, -81.0, "ТОРПЕДНЫЙ ОТСЕК"],
	["missile", "missile compartment", 0.0, 0.0, -81.0, -14.0, "РАКЕТНЫЙ ОТСЕК"],
	["passage", "centre passage", 0.0, 0.0, -14.0, 54.0, "ПРОХОД"],
	["control", "command bay", 0.0, UPPER_Y, -14.0, 0.0, "ЦЕНТРАЛЬНЫЙ ПОСТ"],
	["nav", "navigation room", 0.0, UPPER_Y, 0.0, 8.0, "ШТУРМАНСКАЯ"],
	["steering", "steering gear", 0.0, 0.0, 54.0, 70.0, "РУЛЕВОЙ ОТСЕК"],
	["berthing", "crew's quarters, port", -HULL_X, 0.0, -60.0, -40.0, "КУБРИК"],
	["battery", "officers' country", -HULL_X, 0.0, -40.0, -26.0, "КАЮТ-КОМПАНИЯ"],
	["crew", "mess and galley", -HULL_X, 0.0, -26.0, -12.0, "СТОЛОВАЯ"],
	["rec", "rec room", -HULL_X, 0.0, -12.0, 2.0, "КОМНАТА ОТДЫХА"],
	["reactor", "reactor, port", -HULL_X, 0.0, 2.0, 26.0, "РЕАКТОР №1"],
	["engine", "turbine room, port", -HULL_X, 0.0, 26.0, 54.0, "ТУРБИНА №1"],
	["berthing2", "crew's quarters, starboard", HULL_X, 0.0, -60.0, -40.0, "КУБРИК"],
	["sickbay", "sick bay", HULL_X, 0.0, -40.0, -26.0, "ЛАЗАРЕТ"],
	["sauna", "gym, sauna and pool", HULL_X, 0.0, -26.0, -12.0, "САУНА И БАССЕЙН"],
	["radio", "radio room", HULL_X, 0.0, -12.0, 2.0, "РАДИОРУБКА"],
	["reactor2", "reactor, starboard", HULL_X, 0.0, 2.0, 26.0, "РЕАКТОР №2"],
	["engine2", "turbine room, starboard", HULL_X, 0.0, 26.0, 54.0, "ТУРБИНА №2"],
]
## The doors along the hulls, between neighbours in ROOMS.
const LINE_DOORS := [[0, 1], [1, 2], [2, 3], [3, 6], [4, 5], [7, 8], [8, 9], [9, 10], [10, 11], [11, 12], [13, 14], [14, 15], [15, 16], [16, 17], [17, 18]]
## Cross passages: [centre room, hull room, z] for each side.
const CROSS := [[2, 7, -50.0], [2, 13, -50.0], [3, 10, -7.5], [3, 16, -7.5], [3, 12, 45.0], [3, 18, 45.0]]


static func lay_out(i: SubInterior) -> void:
	for r: Array in ROOMS:
		i.compartments.append({"type": r[0], "name": r[1], "x": r[2], "y": r[3], "z0": r[4], "z1": r[5], "sign": r[6]})
	var n := 0
	for pair: Array in LINE_DOORS:
		i.door_links["d%d" % n] = pair
		i._room_links.append(["d%d" % n, pair[0], pair[1]])
		n += 1
	for c: Array in CROSS:
		i.door_links["x%d" % n] = [c[0], c[1]]
		i._room_links.append(["x%d" % n, c[0], c[1]])
		n += 1
	i._room_links.append(["", 3, 4]) # the hatch up to the command hull is always open


static func build(i: SubInterior) -> void:
	var hatch := Rect2(-0.45, HATCH_Z, 0.9, 0.9)
	for k in i.compartments.size():
		var c: Dictionary = i.compartments[k]
		var root := Node3D.new()
		root.name = "room_%s" % c.type
		root.position = Vector3(c.x, c.y, 0.0)
		i.add_child(root)
		i._rooms.append(root)
		i._at = root
		var gaps: Array = []
		for j in CROSS.size():
			var cr: Array = CROSS[j]
			if cr[0] == k:
				gaps.append([signf(i.compartments[cr[1]].x), cr[2]])
			elif cr[1] == k:
				gaps.append([-signf(c.x), cr[2]])
		i._compartment(c.z0, c.z1, "%s\n%s" % [c.sign, c.name.to_upper()], hatch if c.type == "passage" else Rect2(), gaps, hatch if c.type == "control" else Rect2())
		i._bulkhead(c.z0, _door_at(i, k, true))
		if not _has_door_aft(i, k):
			i._bulkhead(c.z1, "")
	for k in i.compartments.size():
		i._at = i._rooms[k]
		_fit(i, i.compartments[k], hatch)
		var c: Dictionary = i.compartments[k]
		if c.z1 - c.z0 < 50.0: # the long rooms are dressed by their own gear
			i._dressing(c, hatch if c.type == "passage" else Rect2())
		var doors_in_walls: Array = []
		for cr: Array in CROSS:
			if cr[0] == k or cr[1] == k:
				doors_in_walls.append(float(cr[2]))
		i._clutter(c, doors_in_walls)
	i._at = i
	_cross_passages(i)
	var ct: Dictionary = i.comp("control")
	for s in 6:
		i.spawn_points.append(Vector3(-0.6 + (s % 3) * 0.6, UPPER_Y + 0.1, ct.z1 - 2.6 - (s / 3) * 0.7))
	var tb: Dictionary = i.comp("engine")
	i._motor_sound = Sfx.loop_at(i, "motor_loop", Vector3(tb.x, 1.0, (tb.z0 + tb.z1) * 0.5), -80.0, 14.0)


## The door in a room's fore or after bulkhead, when one leads on: built once, by the after room.
static func _door_at(i: SubInterior, k: int, _fore: bool) -> String:
	for id: String in i.door_links:
		if id.begins_with("d") and i.door_links[id][1] == k:
			return id
	return ""


static func _has_door_aft(i: SubInterior, k: int) -> bool:
	for id: String in i.door_links:
		if id.begins_with("d") and i.door_links[id][0] == k:
			return true
	return false


## Each compartment's own fittings.
static func _fit(i: SubInterior, c: Dictionary, hatch: Rect2) -> void:
	var mid: float = (c.z0 + c.z1) * 0.5
	match c.type:
		"sonar":
			_sonar_room(i, c)
		"fwd_torpedo":
			i._torpedo_room(c, false)
		"missile":
			_silos(i, c)
		"passage":
			_ladder(i, hatch)
			i._rack("passage", c.z0 + 4.0)
			var crate := PartsCrate.new()
			crate.position = Vector3(-1.35, 0, 30.0)
			i._at.add_child(crate)
			_cabinets(i, c)
		"control":
			_command_bay(i, c)
			_notebooks(i, c)
			_bridge_ladder(i, c)
		"nav":
			i._nav_room(c, false)
			i._add_station(AirStation.new().setup("air", "Air panel"), Vector3(1.8, 0, c.z0 + 1.3))
		"steering":
			Build.cyl(i._at, 0.55, 3.0, Vector3(0, 1.4, mid), SubInterior.DARK)
			Build.hitbox(i._at, Vector3(1.0, 2.6, 1.0), Vector3(0, 1.3, mid))
			for side in [-1.0, 1.0]:
				Build.box(i._at, Vector3(0.4, 1.8, 5.0), Vector3(side * 1.7, 0.9, mid), Color("#4E5550"))
			i._rack(c.type, c.z0 + 1.3)
		"berthing", "berthing2":
			i._berthing(c, {"side": -signf(c.x), "z": CROSS[0][2]}) # no bunks across the cross passage's door
		"battery":
			i._battery(c)
		"crew":
			i._crew(c)
		"rec":
			i._rec_room(c)
		"sickbay":
			for z in [c.z0 + 3.0, c.z0 + 6.5, c.z0 + 10.0]:
				Build.box(i._at, Vector3(0.9, 0.7, 2.0), Vector3(1.4, 0.35, z), Color("#E8E4DA"))
			Build.box(i._at, Vector3(0.1, 0.5, 0.5), Vector3(-1.95, 1.7, mid), Color("#B23A2E"), false)
			i._rack(c.type, c.z1 - 1.4)
		"sauna":
			_leisure(i, c)
		"radio":
			for z in [c.z0 + 2.0, c.z0 + 4.0, c.z0 + 6.0, c.z0 + 8.0]:
				Build.box(i._at, Vector3(0.6, 1.9, 1.7), Vector3(1.6, 0.95, z), Color("#4A5248"))
				Build.sphere(i._at, 0.04, Vector3(1.28, 1.5, z), UiKit.GOOD, 2.0)
		"reactor", "reactor2":
			_reactor_room(i, c)
		"engine", "engine2":
			_turbine_room(i, c)


static func _sonar_room(i: SubInterior, c: Dictionary) -> void:
	for side in [-1.0, 1.0]:
		for z in [c.z0 + 2.0, c.z0 + 4.5]:
			Build.box(i._at, Vector3(0.6, 1.9, 1.8), Vector3(side * 1.6, 0.95, z), Color("#3A4340"))
			Build.box(i._at, Vector3(0.03, 0.5, 0.8), Vector3(side * 1.28, 1.4, z), Color("#113322"), false)
	i._rack(c.type, c.z1 - 1.0)


## Twenty missile tubes, two rows of ten, floor to deckhead, an aisle between.
static func _silos(i: SubInterior, c: Dictionary) -> void:
	var col := Color("#8C9A94")
	for k in 10:
		var z: float = lerpf(c.z0 + 6.0, c.z1 - 6.0, k / 9.0)
		for side in [-1.0, 1.0]:
			if absf(z - -50.0) < 2.8: # clear of the cross passage
				continue
			var x: float = side * 1.28
			Build.cyl(i._at, 0.62, SubInterior.DECK_HEIGHT, Vector3(x, SubInterior.DECK_HEIGHT * 0.5, z), col)
			Build.hitbox(i._at, Vector3(1.1, SubInterior.DECK_HEIGHT, 1.1), Vector3(x, SubInterior.DECK_HEIGHT * 0.5, z))
			Build.cyl(i._at, 0.66, 0.08, Vector3(x, 0.4, z), Color("#6E7F78"))
			Build.cyl(i._at, 0.66, 0.08, Vector3(x, 2.2, z), Color("#6E7F78"))
			var face: float = side * 0.62
			Build.wheel(i._at, 0.12, Vector3(face, 1.05, z), Color("#B23A2E"), Vector3.RIGHT if side < 0.0 else Vector3.LEFT)
			Build.box(i._at, Vector3(0.05, 0.3, 0.22), Vector3(face, 0.7, z + 0.3), Color("#3A4340"), false)
			Build.sphere(i._at, 0.02, Vector3(face - side * 0.03, 0.78, z + 0.3), UiKit.GOOD, 2.0)
			Build.cyl(i._at, 0.02, 2.0, Vector3(face, 1.6, z - 0.35), Color("#2B2B26"))
			var tube_no := k * 2 + (0 if side < 0.0 else 1) + 1
			var lab := Build.label(i._at, "%d" % tube_no, Vector3(side * 0.64, 1.5, z), 60, Color("#B23A2E"))
			lab.rotation.y = PI / 2.0 if side < 0.0 else -PI / 2.0
	i._rack(c.type, c.z1 - 2.0)


## Grey equipment cabinets down the centre passage, clear of its doors, ladder, rack and crate.
static func _cabinets(i: SubInterior, c: Dictionary) -> void:
	var clear := [-7.5, 45.0, HATCH_Z, 30.0, c.z0 + 4.0]
	var z: float = c.z0 + 2.0
	var k := 0
	while z < c.z1 - 2.0:
		var side := -1.0 if k % 2 == 0 else 1.0
		if not clear.any(func(q: float) -> bool: return absf(q - z) < 1.8):
			var x: float = side * 1.68
			Build.box(i._at, Vector3(0.45, 1.5, 0.9), Vector3(x, 0.75, z), Color("#6B747C"))
			Build.box(i._at, Vector3(0.02, 0.5, 0.6), Vector3(x - side * 0.235, 1.05, z), Color("#0C1418"), false)
			for n in 3:
				Build.sphere(i._at, 0.018, Vector3(x - side * 0.235, 0.6, z - 0.2 + n * 0.2), [UiKit.GOOD, Color("#E8B04A"), Color("#B23A2E")][n], 2.0)
			Build.box(i._at, Vector3(0.02, 0.05, 0.3), Vector3(x - side * 0.235, 1.4, z), Color("#E8E0C8"), false)
		z += 2.6
		k += 1


## The real boat's comforts (public sources): a pine sauna, a small swimming pool, a gym, sun lamps
## and an aviary of songbirds, for months under the ice.
static func _leisure(i: SubInterior, c: Dictionary) -> void:
	var pine := Color("#8A6238")
	Build.box(i._at, Vector3(1.4, 2.2, 4.0), Vector3(1.25, 1.1, c.z0 + 3.0), pine) # the sauna
	Build.box(i._at, Vector3(0.05, 1.9, 0.7), Vector3(0.53, 0.95, c.z0 + 4.2), Color("#6B4A2A"), false) # its door
	Build.sphere(i._at, 0.03, Vector3(0.5, 1.0, c.z0 + 3.95), SubInterior.BRASS)
	# The pool: a tiled tank, blue water, a chrome ladder, a life ring on the wall.
	var pz: float = c.z0 + 7.0
	var tile := Color("#D8E4E8")
	for side in [-1.0, 1.0]:
		Build.box(i._at, Vector3(1.3, 0.6, 0.12), Vector3(-1.2, 0.3, pz + side * 2.0), tile)
	Build.box(i._at, Vector3(0.12, 0.6, 4.1), Vector3(-0.6, 0.3, pz), tile)
	Build.box(i._at, Vector3(1.2, 0.02, 3.9), Vector3(-1.25, 0.5, pz), Color("#2E8FB8"), false)
	Build.box(i._at, Vector3(1.2, 0.03, 3.9), Vector3(-1.25, 0.47, pz), Color("#1D5F80"), false)
	for k in 2:
		Build.cyl(i._at, 0.015, 0.7, Vector3(-0.6, 0.85, pz - 0.15 + k * 0.3), Color("#C8CCCC"))
	Build.wheel(i._at, 0.2, Vector3(-1.93, 1.4, pz), Color("#E2512E"), Vector3.RIGHT)
	Build.label(i._at, "БАССЕЙН\nPOOL", Vector3(-1.94, 1.85, pz), 20, Color("#2B2B26")).rotation.y = PI / 2.0
	# The gym, starboard after the sauna: benches, a rack of weights, a rowing machine.
	for z in [c.z0 + 6.2, c.z0 + 8.4]:
		Build.box(i._at, Vector3(0.6, 0.45, 1.6), Vector3(1.35, 0.23, z), SubInterior.DARK)
		Build.cyl(i._at, 0.02, 1.2, Vector3(1.35, 0.95, z), Color("#8A8F86"), Vector3.RIGHT)
		for side in [-1.0, 1.0]:
			Build.cyl(i._at, 0.16, 0.05, Vector3(1.35 + side * 0.5, 0.95, z), Color("#1E1E1E"), Vector3.RIGHT)
	Build.box(i._at, Vector3(0.5, 0.3, 1.5), Vector3(1.4, 0.15, c.z0 + 10.4), Color("#4A5560"))
	# The aviary: a brass-wire cage of songbirds on the after bulkhead, a sun lamp over the pool.
	var cz: float = c.z1 - 0.5
	Build.box(i._at, Vector3(1.1, 0.06, 0.5), Vector3(-0.9, 1.0, cz), Color("#6B5A44"))
	for k in 6:
		Build.cyl(i._at, 0.008, 0.8, Vector3(-1.4 + k * 0.2, 1.43, cz), SubInterior.BRASS)
	Build.box(i._at, Vector3(1.1, 0.04, 0.5), Vector3(-0.9, 1.85, cz), SubInterior.BRASS, false)
	for k in 3:
		Build.sphere(i._at, 0.045, Vector3(-1.2 + k * 0.3, 1.2 + (k % 2) * 0.25, cz), [Color("#E8C84A"), Color("#4FA8D8"), Color("#E8E0C8")][k])
	Build.label(i._at, "КАНАРЕЙКИ", Vector3(-0.9, 2.0, cz - 0.27), 18, Color("#2B2B26")).rotation.y = PI
	Build.box(i._at, Vector3(0.8, 0.06, 0.3), Vector3(-1.2, SubInterior.DECK_HEIGHT - 0.2, pz), Color("#2E3A44"), false)
	Build.box(i._at, Vector3(0.7, 0.02, 0.2), Vector3(-1.2, SubInterior.DECK_HEIGHT - 0.24, pz), Color("#F2E0A8"), false)
	i._rack(c.type, c.z1 - 1.4)


static func _reactor_room(i: SubInterior, c: Dictionary) -> void:
	var mid: float = (c.z0 + c.z1) * 0.5
	var shield := Color("#5A6048")
	for side in [-1.0, 1.0]:
		Build.box(i._at, Vector3(0.5, 2.5, 16.0), Vector3(side * 1.65, 1.25, mid), shield)
	for z in [mid - 4.0, mid, mid + 4.0]:
		Build.label(i._at, "☢", Vector3(1.38, 1.6, z), 90, Color("#E8B04A")).rotation.y = -PI / 2.0
		Build.label(i._at, "☢", Vector3(-1.38, 1.6, z), 90, Color("#E8B04A")).rotation.y = PI / 2.0
	Build.sphere(i._at, 0.08, Vector3(0, 2.3, mid), Color("#E8B04A"), 2.0)
	# Steam and primary-coolant lines over the shields, valves and gauges on their faces.
	for side in [-1.0, 1.0]:
		for k in 3:
			Build.cyl(i._at, 0.11 - k * 0.025, 16.0, Vector3(side * (1.75 - k * 0.22), 2.62 + k * 0.04, mid), [Color("#B8B4A8"), Color("#C9A04A"), RED_PIPE][k], Vector3.BACK)
		var z: float = mid - 7.0
		var n := 0
		while z < mid + 7.5:
			var x: float = side * 1.39
			if n % 3 == 0:
				Build.wheel(i._at, 0.13, Vector3(x, 1.25, z), Color("#B23A2E"), Vector3.LEFT if side > 0.0 else Vector3.RIGHT)
			elif n % 3 == 1:
				for dy in [0.0, 0.3]:
					Build.cyl(i._at, 0.07, 0.03, Vector3(x, 1.0 + dy, z), SubInterior.BRASS, Vector3.RIGHT)
			else:
				Build.cyl(i._at, 0.03, 2.4, Vector3(x - side * 0.02, 1.2, z), Color("#8A8F86"))
			z += 1.1
			n += 1


static func _turbine_room(i: SubInterior, c: Dictionary) -> void:
	var z0: float = c.z0 + 3.0
	var z1: float = c.z1 - 11.0 # clear of the cross passage's door
	# Steam down from the reactor into the turbine, the condenser under it, gauge boards.
	for k in 4:
		var z := z0 + 1.5 + k * (z1 - z0 - 3.0) / 3.0
		Build.cyl(i._at, 0.12, 0.9, Vector3(1.05, 2.2, z), Color("#B8B4A8"))
		Build.cyl(i._at, 0.17, 0.08, Vector3(1.05, 1.82, z), SubInterior.BRASS)
	Build.cyl(i._at, 0.14, z1 - z0, Vector3(1.05, 2.55, (z0 + z1) * 0.5), Color("#B8B4A8"), Vector3.BACK)
	Build.box(i._at, Vector3(1.2, 0.18, z1 - z0 - 2.0), Vector3(1.05, 0.09, (z0 + z1) * 0.5), Color("#4E555C"), false)
	for z in [c.z1 - 6.5, c.z1 - 2.6]: # clear of the cross passage at z1 - 9
		Build.box(i._at, Vector3(0.25, 1.3, 1.6), Vector3(1.75, 1.25, z), Color("#5A6048"))
		for k in 4:
			Build.cyl(i._at, 0.07, 0.03, Vector3(1.61, 1.5 - (k / 2) * 0.35, z - 0.3 + (k % 2) * 0.6), SubInterior.BRASS, Vector3.RIGHT)
	Build.cyl(i._at, 0.85, z1 - z0, Vector3(1.05, 1.0, (z0 + z1) * 0.5), Color("#6E756C"), Vector3.BACK)
	Build.hitbox(i._at, Vector3(1.6, 2.0, z1 - z0), Vector3(1.05, 1.0, (z0 + z1) * 0.5))
	for k in 4:
		Build.cyl(i._at, 0.95, 0.18, Vector3(1.05, 1.0, z0 + 2.0 + k * (z1 - z0 - 4.0) / 3.0), SubInterior.BRASS, Vector3.BACK)
	i._rack(c.type, c.z0 + 1.3, true)
	if c.type == "engine":
		i._add_station(ReactorStation.new().setup("engine", "Reactor controls"), Vector3(0, 0, c.z1 - 0.25), -PI / 2.0)


## The ladder from the centre passage up into the command bay.
static func _ladder(i: SubInterior, hatch: Rect2) -> void:
	var ladder := Ladder.new()
	ladder.name = "ladder_command"
	i.main_ladder = ladder
	i._at.add_child(ladder)
	var lz := hatch.position.y - 0.02
	var top := UPPER_Y
	for side in [-0.25, 0.25]:
		Build.cyl(ladder, 0.03, top, Vector3(side, top * 0.5, lz), Color("#8A8F86"))
	for k in 8:
		Build.cyl(ladder, 0.02, 0.5, Vector3(0, 0.3 + k * 0.33, lz), Color("#8A8F86"), Vector3.RIGHT)
	Build.hitbox(ladder, Vector3(0.7, 2.4, 0.25), Vector3(0, 1.2, lz))
	var hz := hatch.get_center().y
	ladder.top_y = top
	ladder.bottom_path = [Vector3(0, 0.05, hz + 0.75), Vector3(0, 0.05, hz), Vector3(0, top + 0.05, hz), Vector3(0, top + 0.05, hz + 0.95)]
	var ry := top + 0.45
	for dz in [hatch.position.y - 0.03, hatch.end.y + 0.03]:
		Build.box(ladder, Vector3(hatch.size.x + 0.1, 0.9, 0.05), Vector3(0, ry, dz), SubInterior.BRASS)
	for dx in [hatch.position.x - 0.03, hatch.end.x + 0.03]:
		Build.box(ladder, Vector3(0.05, 0.9, hatch.size.y), Vector3(dx, ry, hatch.get_center().y), SubInterior.BRASS)


## Up through the fin to the deck, for walking the casing on the surface.
static func _bridge_ladder(i: SubInterior, c: Dictionary) -> void:
	var z: float = c.z1 - 1.0
	for side in [-0.2, 0.2]:
		Build.cyl(i._at, 0.03, SubInterior.DECK_HEIGHT, Vector3(1.3 + side, SubInterior.DECK_HEIGHT * 0.5, z), Color("#8A8F86"))
	for k in 7:
		Build.cyl(i._at, 0.02, 0.4, Vector3(1.3, 0.3 + k * 0.33, z), Color("#8A8F86"), Vector3.RIGHT)
	Build.cyl(i._at, 0.42, 0.12, Vector3(1.3, SubInterior.DECK_HEIGHT - 0.06, z - 0.1), Color("#3A3F38"))
	var hatch := GunStation.BridgeHatch.new()
	hatch.position = Vector3(1.3, SubInterior.DECK_HEIGHT - 0.06, z - 0.1)
	i._at.add_child(hatch)
	Build.area(hatch, Vector3(0.8, 0.4, 0.8), Vector3.ZERO)


## The central post as in The Hunt for Red October (Blaney: a realistic layout): helmsman and
## planesman side by side at yokes facing the bow under a bank of gauges, the skipper's chair
## and the periscope stand behind them, sonar to port and fire control to starboard.
static func _command_bay(i: SubInterior, c: Dictionary) -> void:
	var z0: float = c.z0
	var z1: float = c.z1
	var steel := Color("#4A5560")
	Build.box(i._at, Vector3(2.5, 1.9, 0.4), Vector3(0, 0.95, z0 + 0.25), steel) # the gauge bank
	for k in 6:
		var x := -1.0 + k * 0.4
		Build.cyl(i._at, 0.1, 0.03, Vector3(x, 1.25, z0 + 0.46), Color("#151515"), Vector3.BACK)
		Build.cyl(i._at, 0.11, 0.02, Vector3(x, 1.25, z0 + 0.455), SubInterior.BRASS, Vector3.BACK)
		Build.sphere(i._at, 0.02, Vector3(x, 0.95, z0 + 0.46), [UiKit.GOOD, Color("#E8B04A"), Color("#B23A2E")][k % 3], 2.0)
	i._gauge_board(Vector3(-0.6, 1.68, z0 + 0.47), ["depth", "ordered"])
	i._gauge_board(Vector3(0.6, 1.68, z0 + 0.47), ["speed", "heading"])
	var plane := YokeStation.new().setup("dive", "Planesman's yoke", "helm_dive") as YokeStation
	plane.role = "dive"
	i._add_station(plane, Vector3(-0.6, 0, z0 + 1.65))
	var helm := YokeStation.new().setup("helm", "Helmsman's yoke", "helm_dive") as YokeStation
	helm.role = "helm"
	i._add_station(helm, Vector3(0.6, 0, z0 + 1.65))
	i._add_station(BilgeStation.new().setup("bilge", "Bilge pump"), Vector3(-1.62, 0, z0 + 0.3), PI / 2.0)
	# The periscope stand: a low dais with a brass rail, the attack scope beside the search scope.
	var pz: float = z0 + 5.4
	Build.cyl(i._at, 1.05, 0.1, Vector3(0, 0.05, pz), Color("#2E3A44"), Vector3.UP)
	for k in 9:
		var a := lerpf(-1.2, 1.2, k / 8.0) # posts round the forward arc, open aft
		Build.cyl(i._at, 0.025, 0.95, Vector3(sin(a), 0.47, pz - cos(a)), SubInterior.BRASS)
		if k > 0: # the rail along the post tops
			var b := lerpf(-1.2, 1.2, (k - 0.5) / 8.0)
			Build.box(i._at, Vector3(0.31, 0.05, 0.05), Vector3(sin(b), 0.95, pz - cos(b)), SubInterior.BRASS, false).rotation.y = -b
	i._add_station(PeriscopeStation.new().setup("periscope", "Periscope", ""), Vector3(0, 0, pz))
	Build.cyl(i._at, 0.09, SubInterior.DECK_HEIGHT, Vector3(0.55, SubInterior.DECK_HEIGHT * 0.5, pz + 0.5), Color("#6E756C"))
	# The captain's chair, to port of the stand where he can see both yokes (the hologram is in the navigation room).
	i._add_station(CaptainStation.new().setup("captain", "Captain's chair"), Vector3(-1.15, 0, z0 + 4.6))
	i._add_station(SonarStation.new().setup("sonar", "Sonar", ""), Vector3(-1.85, 0, z0 + 7.4))
	i._add_station(TdcStation.new().setup("tdc", "Fire control", ""), Vector3(1.55, 0, z0 + 4.6))
	i._add_station(BallastStation.new().setup("ballast", "Ballast manifold"), Vector3(-1.85, 0, z1 - 1.8))
	i._add_station(NavStation.new().setup("nav", "Chart table"), Vector3(1.4, 0, z1 - 1.6))
	var mic := PaMic.new() # the PA, on the after bulkhead to port of the door
	mic.position = Vector3(-1.05, 0, z1 - 0.12)
	i._at.add_child(mic)
	i._rack(c.type, z0 + 9.6)
	# Cable trays and pipe runs along the deckhead, the length of the bay.
	for x in [-1.25, -1.05, 1.05, 1.25]:
		Build.cyl(i._at, 0.04, z1 - z0 - 0.4, Vector3(x, 2.3, (z0 + z1) * 0.5), Color("#8A8F86") if absf(x) > 1.1 else Color("#B23A2E"), Vector3.BACK)
	for x in [-0.7, 0.7]:
		Build.box(i._at, Vector3(0.3, 0.05, z1 - z0 - 0.4), Vector3(x, 2.42, (z0 + z1) * 0.5), Color("#3A3F38"), false)


static func _notebooks(i: SubInterior, c: Dictionary) -> void:
	var mate := NotebookStation.new().setup("first_mate", "First mate's list") as NotebookStation
	mate.kind = "first_mate"
	i._add_station(mate, Vector3(-0.75, 0, c.z0 + 7.2))
	var skip := NotebookStation.new().setup("skipper", "Skipper's notebook") as NotebookStation
	skip.kind = "skipper"
	i._add_station(skip, Vector3(0.75, 0, c.z0 + 7.2))


## The short passages joining the centre rooms to the main hulls, each with its door.
static func _cross_passages(i: SubInterior) -> void:
	var h := SubInterior.DECK_HEIGHT
	for j in CROSS.size():
		var cr: Array = CROSS[j]
		var side := signf(i.compartments[cr[1]].x)
		var z: float = cr[2]
		var inner := SubInterior.HALF_WIDTH + 0.2
		var mid := side * (HULL_X * 0.5)
		var run := HULL_X - SubInterior.HALF_WIDTH * 2.0 - 0.4 + 0.02
		var w := WatertightDoor.WIDTH
		# It belongs to the hull room, so it's hidden and shown with it.
		var root: Node3D = i._rooms[cr[0]]
		Build.box(root, Vector3(run, 0.2, w + 0.3), Vector3(mid, -0.103, z), SubInterior.FLOOR) # a hair below the rooms' floors, which it meets
		Build.box(root, Vector3(run, 0.2, w + 0.3), Vector3(mid, WatertightDoor.HEIGHT + 0.1, z), SubInterior.CEILING)
		for dz in [-1.0, 1.0]:
			Build.box(root, Vector3(run, h, 0.15), Vector3(mid, h * 0.5, z + dz * (w * 0.5 + 0.08)), SubInterior.WALL)
		var door := WatertightDoor.new().setup("x%d" % (j + LINE_DOORS.size()))
		door.position = Vector3(side * inner, 0, z)
		door.rotation.y = PI / 2.0
		root.add_child(door)
		i.doors["x%d" % (j + LINE_DOORS.size())] = door


## The band: true when the crew's instruments, not a record, are what's playing.
static func band_audible(crew: Dictionary) -> bool:
	var rec: Array = Jukebox.RECORDS[int(crew.get("jukebox", 0)) % Jukebox.RECORDS.size()]
	return rec[1] == "" or rec[1] == "foggy_dew"


static var _band: Node3D


## Eight sailors in the rec room with the instruments, and the rest of the forty standing round;
## they play The Foggy Dew on the band's clock, or play along to another record.
static func sync_band(i: SubInterior, crew: Dictionary) -> void:
	if i.sub_class.key != "typhoon":
		return
	var want: bool = crew.get("band", false)
	if not is_instance_valid(_band):
		_band = null
	if want and _band == null:
		_band = BandCrew.new()
		_band.interior = i
		var c: Dictionary = i.comp(BAND_ROOM)
		_band.position = Vector3(c.x, 0.0, (c.z0 + c.z1) * 0.5)
		i._rooms[i.comp_index(BAND_ROOM)].add_child(_band)
		_band.position.x = 0.0
	elif not want and _band != null:
		_band.queue_free()
		_band = null
