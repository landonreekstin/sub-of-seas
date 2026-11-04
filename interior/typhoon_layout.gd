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
const UPPER_Y := SubInterior.CT_FLOOR
const HATCH_Z := -11.0 ## the ladder from the passage up into the command hull
const SAILORS_PER_ROOM := 3
const SOVIET_SHIRT := Color("#27354F")
const BAND_ROOM := "rec"

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
	["sauna", "gym and sauna", HULL_X, 0.0, -26.0, -12.0, "САУНА"],
	["radio", "radio room", HULL_X, 0.0, -12.0, 2.0, "РАДИОРУБКА"],
	["reactor2", "reactor, starboard", HULL_X, 0.0, 2.0, 26.0, "РЕАКТОР №2"],
	["engine2", "turbine room, starboard", HULL_X, 0.0, 26.0, 54.0, "ТУРБИНА №2"],
]
## The doors along the hulls, between neighbours in ROOMS.
const LINE_DOORS := [[0, 1], [1, 2], [2, 3], [3, 6], [4, 5], [7, 8], [8, 9], [9, 10], [10, 11], [11, 12], [13, 14], [14, 15], [15, 16], [16, 17], [17, 18]]
## Cross passages: [centre room, hull room, z] for each side.
const CROSS := [[2, 7, -50.0], [2, 13, -50.0], [3, 10, -5.0], [3, 16, -5.0], [3, 12, 45.0], [3, 18, 45.0]]


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
		"control":
			i._control_room(c, Rect2())
			_notebooks(i, c)
			_bridge_ladder(i, c)
		"nav":
			i._nav_room(c)
			i._add_station(AirStation.new().setup("air", "Air panel"), Vector3(1.8, 0, c.z0 + 1.3))
		"steering":
			Build.cyl(i._at, 0.9, 3.0, Vector3(0, 1.4, mid), SubInterior.DARK)
			for side in [-1.0, 1.0]:
				Build.box(i._at, Vector3(0.4, 1.8, 5.0), Vector3(side * 1.5, 0.9, mid), Color("#4E5550"))
			i._rack(c.type, c.z0 + 1.3)
		"berthing", "berthing2":
			i._berthing(c)
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
			Build.box(i._at, Vector3(1.4, 2.2, 4.0), Vector3(1.25, 1.1, c.z0 + 3.0), Color("#8A6238"))
			for z in [c.z1 - 3.0, c.z1 - 5.5]:
				Build.box(i._at, Vector3(0.7, 0.5, 1.8), Vector3(-1.4, 0.25, z), SubInterior.DARK) # weight benches
			i._rack(c.type, c.z1 - 1.4)
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
			var tube_no := k * 2 + (0 if side < 0.0 else 1) + 1
			var lab := Build.label(i._at, "%d" % tube_no, Vector3(side * 0.64, 1.5, z), 60, Color("#B23A2E"))
			lab.rotation.y = PI / 2.0 if side < 0.0 else -PI / 2.0
	i._rack(c.type, c.z1 - 2.0)


static func _reactor_room(i: SubInterior, c: Dictionary) -> void:
	var mid: float = (c.z0 + c.z1) * 0.5
	var shield := Color("#5A6048")
	for side in [-1.0, 1.0]:
		Build.box(i._at, Vector3(0.5, 2.5, 16.0), Vector3(side * 1.65, 1.25, mid), shield)
	for z in [mid - 4.0, mid, mid + 4.0]:
		Build.label(i._at, "☢", Vector3(1.38, 1.6, z), 90, Color("#E8B04A")).rotation.y = -PI / 2.0
		Build.label(i._at, "☢", Vector3(-1.38, 1.6, z), 90, Color("#E8B04A")).rotation.y = PI / 2.0
	Build.sphere(i._at, 0.08, Vector3(0, 2.3, mid), Color("#E8B04A"), 2.0)


static func _turbine_room(i: SubInterior, c: Dictionary) -> void:
	var z0: float = c.z0 + 3.0
	var z1: float = c.z1 - 8.0
	Build.cyl(i._at, 0.85, z1 - z0, Vector3(1.05, 1.0, (z0 + z1) * 0.5), Color("#6E756C"), Vector3.BACK)
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
		Build.box(root, Vector3(run, 0.2, w + 0.3), Vector3(mid, -0.1, z), SubInterior.FLOOR)
		Build.box(root, Vector3(run, 0.2, w + 0.3), Vector3(mid, WatertightDoor.HEIGHT + 0.1, z), SubInterior.CEILING)
		for dz in [-1.0, 1.0]:
			Build.box(root, Vector3(run, h, 0.15), Vector3(mid, h * 0.5, z + dz * (w * 0.5 + 0.08)), SubInterior.WALL)
		var door := WatertightDoor.new().setup("x%d" % (j + LINE_DOORS.size()))
		door.position = Vector3(side * inner, 0, z)
		door.rotation.y = PI / 2.0
		root.add_child(door)
		i.doors["x%d" % (j + LINE_DOORS.size())] = door


## Sailors for a room, the first time it's seen with the full crew aboard. Only rooms in sight
## have them at all: 160 men wouldn't run; three in each room you can see do.
static func people_room(i: SubInterior, k: int) -> void:
	if Game.instance == null or not Game.instance.crew.get("full_crew", false):
		return
	var root := i._rooms[k]
	if root.has_meta("peopled"):
		return
	root.set_meta("peopled", true)
	var c: Dictionary = i.compartments[k]
	var rng := RandomNumberGenerator.new()
	rng.seed = k * 97 + 3
	for n in SAILORS_PER_ROOM:
		var look := {"build": rng.randi() % 4, "skin": rng.randi() % 3, "hair": rng.randi() % 7, "hair_col": rng.randi() % 7,
			"beard": rng.randi() % 3, "hat": "watch", "hue": 0.62}
		var v := i._sailor(look)
		i.remove_child(v)
		root.add_child(v)
		v.position = Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(c.z0 + 2.0, c.z1 - 2.0))
		v.rotation.y = rng.randf() * TAU


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
