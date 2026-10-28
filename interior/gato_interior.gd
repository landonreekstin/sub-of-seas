class_name GatoInterior
extends Node3D
## Greybox Gato-class interior for the first-dive slice, built from primitives.
## Bow is -Z. Main deck floor at y = 0. Compartments fore to aft:
##   Forward Torpedo Room  z -22 .. -8
##   Control Room          z  -8 ..  0   (Conning Tower above, ladder through a hatch)
##   Engine Room           z   0 .. 14

const HALF_WIDTH := 2.0
const DECK_HEIGHT := 2.6
const CT_FLOOR := 2.8
const HATCH := Rect2(-0.45, -5.0, 0.9, 0.9) # x, z, w, d of the control room → conning tower hatch

const WALL := Color("#9DB59A")
const FLOOR := Color("#5E6B5C")
const CEILING := Color("#B5C4B0")
const BRASS := Color("#C9A04A")
const PIPE := Color("#D8D2C0")
const RED := Color("#B23A2E")
const DARK := Color("#3A3F38")
const LIGHT := Color("#FFD9A0")
## Watertight compartments, fore to aft, as the hull damage model sees them.
const COMPARTMENTS := [
	{"name": "forward torpedo room", "z0": -22.0, "z1": -8.0},
	{"name": "control room", "z0": -8.0, "z1": 0.0},
	{"name": "engine room", "z0": 0.0, "z1": 14.0},
]
const DOOR_LINKS := {"fwd": [0, 1], "aft": [1, 2]}

var stations := {} ## station_id -> Station, in build order
var doors := {} ## door_id -> WatertightDoor
var spawn_points: Array[Vector3] = []
var _gauges := {} ## kind -> Array[Label3D]
var damage: DamageView
var _lights: Array[OmniLight3D] = []
var _flicker := 0.0


func _ready() -> void:
	_build_environment()
	_compartment(-22.0, -8.0, "FORWARD TORPEDO ROOM")
	_compartment(-8.0, 0.0, "CONTROL ROOM", HATCH)
	_compartment(0.0, 14.0, "ENGINE ROOM")
	_bulkhead(-22.0, "")
	_bulkhead(-8.0, "fwd")
	_bulkhead(0.0, "aft")
	_bulkhead(14.0, "")
	_torpedo_room()
	_control_room()
	_conning_tower()
	_engine_room()
	damage = DamageView.new()
	damage.name = "Damage"
	damage.interior = self
	add_child(damage)
	for l in find_children("*", "OmniLight3D", true, false):
		_lights.append(l)
		l.set_meta("energy", l.light_energy)
	for i in 6:
		spawn_points.append(Vector3(-0.6 + (i % 3) * 0.6, 0.1, -2.6 - (i / 3) * 0.7))


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0A0C0A")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6E7F6A")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# --- Shell -----------------------------------------------------------------

func _compartment(z0: float, z1: float, title: String, ceiling_hole := Rect2()) -> void:
	var length := z1 - z0
	var mid := (z0 + z1) * 0.5
	Build.box(self, Vector3(HALF_WIDTH * 2.0 + 0.4, 0.2, length), Vector3(0, -0.1, mid), FLOOR)
	for side in [-1.0, 1.0]:
		Build.box(self, Vector3(0.2, DECK_HEIGHT + 0.2, length), Vector3(side * (HALF_WIDTH + 0.1), DECK_HEIGHT * 0.5, mid), WALL)
		# Angled shoulders make the box read as a round pressure hull.
		var top := Build.box(self, Vector3(0.95, 0.12, length), Vector3(side * 1.72, DECK_HEIGHT - 0.2, mid), WALL, false)
		top.rotation.z = side * deg_to_rad(40.0)
		var low := Build.box(self, Vector3(0.6, 0.12, length), Vector3(side * 1.86, 0.16, mid), FLOOR, false)
		low.rotation.z = side * deg_to_rad(-45.0)
		# Pipe runs.
		Build.cyl(self, 0.05, length, Vector3(side * 1.35, DECK_HEIGHT - 0.12, mid), BRASS, Vector3.BACK)
		Build.cyl(self, 0.08, length, Vector3(side * 1.1, DECK_HEIGHT - 0.1, mid), PIPE, Vector3.BACK)
	_slab(DECK_HEIGHT + 0.1, z0, z1, ceiling_hole, CEILING)
	# Lights: a warm bulb every few metres.
	var n := maxi(1, roundi(length / 5.0))
	for i in n:
		var z := z0 + length * (i + 0.5) / n
		Build.sphere(self, 0.08, Vector3(0, DECK_HEIGHT - 0.05, z), LIGHT, 3.0)
	var light := OmniLight3D.new()
	light.light_color = LIGHT
	light.light_energy = 1.4
	light.omni_range = maxf(7.0, length * 0.75)
	light.position = Vector3(0, DECK_HEIGHT - 0.3, mid)
	add_child(light)
	# Label3D reads from +Z: the aft-wall sign turns to face forward.
	Build.label(self, title, Vector3(0, DECK_HEIGHT - 0.25, z1 - 0.13), 40, Color("#2B2B26")).rotation.y = PI
	Build.label(self, title, Vector3(0, DECK_HEIGHT - 0.25, z0 + 0.13), 40, Color("#2B2B26"))


## A horizontal slab at height `y` spanning the hull width, with an optional hole.
func _slab(y: float, z0: float, z1: float, hole: Rect2, color: Color) -> void:
	var w := HALF_WIDTH * 2.0 + 0.4
	if hole.size == Vector2.ZERO:
		Build.box(self, Vector3(w, 0.2, z1 - z0), Vector3(0, y, (z0 + z1) * 0.5), color)
		return
	var hx0 := hole.position.x
	var hx1 := hole.end.x
	var hz0 := hole.position.y
	var hz1 := hole.end.y
	Build.box(self, Vector3(w, 0.2, hz0 - z0), Vector3(0, y, (z0 + hz0) * 0.5), color)
	Build.box(self, Vector3(w, 0.2, z1 - hz1), Vector3(0, y, (hz1 + z1) * 0.5), color)
	var lw := hx0 + w * 0.5
	Build.box(self, Vector3(lw, 0.2, hz1 - hz0), Vector3(-w * 0.5 + lw * 0.5, y, (hz0 + hz1) * 0.5), color)
	var rw := w * 0.5 - hx1
	Build.box(self, Vector3(rw, 0.2, hz1 - hz0), Vector3(hx1 + rw * 0.5, y, (hz0 + hz1) * 0.5), color)


func _bulkhead(z: float, door_id: String) -> void:
	var h := DECK_HEIGHT + 0.2
	if door_id == "":
		Build.box(self, Vector3(HALF_WIDTH * 2.0, h, 0.2), Vector3(0, h * 0.5 - 0.1, z), WALL)
		return
	var dw := WatertightDoor.WIDTH * 0.5
	var side_w := HALF_WIDTH - dw
	for side in [-1.0, 1.0]:
		Build.box(self, Vector3(side_w, h, 0.2), Vector3(side * (dw + side_w * 0.5), h * 0.5 - 0.1, z), WALL)
	var top_h := h - WatertightDoor.HEIGHT
	Build.box(self, Vector3(dw * 2.0, top_h, 0.2), Vector3(0, WatertightDoor.HEIGHT + top_h * 0.5 - 0.1, z), WALL)
	var door := WatertightDoor.new().setup(door_id)
	door.position = Vector3(0, 0, z)
	add_child(door)
	doors[door_id] = door


func _add_station(s: Station, pos: Vector3, rot_y := 0.0) -> Station:
	s.position = pos
	s.rotation.y = rot_y
	add_child(s)
	stations[s.station_id] = s
	return s


# --- Compartments ----------------------------------------------------------

func _torpedo_room() -> void:
	# Six bow tubes: odd numbers starboard, even port, top to bottom.
	for i in 6:
		var tube := TorpedoTubeStation.new()
		tube.tube_index = i
		tube.setup("tube_%d" % (i + 1), "Torpedo tube %d" % (i + 1), "tubes")
		var x := 0.65 if i % 2 == 0 else -0.65
		var y := 1.95 - (i / 2) * 0.7
		_add_station(tube, Vector3(x, y, -21.9))
	# Reload torpedoes on racks along both sides, bunks above them.
	for side in [-1.0, 1.0]:
		for y in [0.45, 1.05]:
			var t := Build.cyl(self, 0.27, 6.5, Vector3(side * 1.5, y, -15.0), Color("#5D6B4E"), Vector3.BACK, true)
			Build.sphere(t, 0.27, Vector3(0, 3.25, 0), Color("#5D6B4E"))
		Build.box(self, Vector3(0.75, 0.08, 6.0), Vector3(side * 1.55, 1.75, -15.0), Color("#6B5A44"))
		Build.box(self, Vector3(0.7, 0.12, 5.8), Vector3(side * 1.55, 1.85, -15.0), Color("#D8D2C0"), false)
	var rack := ToolRack.new()
	rack.position = Vector3(1.97, 1.3, -9.4)
	add_child(rack)
	# Chain hoist rail down the centre for moving torpedoes.
	Build.box(self, Vector3(0.12, 0.12, 12.0), Vector3(0, DECK_HEIGHT - 0.2, -15.5), DARK, false)


func _control_room() -> void:
	_add_station(DiveStation.new().setup("dive", "Dive planes", "helm_dive"), Vector3(-1.85, 0, -6.0))
	_add_station(HelmStation.new().setup("helm", "Helm", "helm_dive"), Vector3(1.8, 0, -6.0))
	# Gauge boards on the forward bulkhead either side of the door.
	_gauge_board(Vector3(-1.25, 1.7, -7.88), ["depth", "ordered"])
	_gauge_board(Vector3(1.25, 1.7, -7.88), ["speed", "heading"])
	# Chart table (navigation station comes in M3).
	Build.box(self, Vector3(1.0, 0.9, 1.4), Vector3(1.4, 0.45, -1.6), Color("#6B5A44"))
	Build.box(self, Vector3(0.9, 0.02, 1.3), Vector3(1.4, 0.91, -1.6), Color("#E8DFC4"), false)
	_add_station(SonarStation.new().setup("sonar", "Sonar"), Vector3(-1.85, 0, -3.7))
	var rack := ToolRack.new()
	rack.position = Vector3(1.97, 1.3, -3.6)
	add_child(rack)
	# Valve manifold on the port side aft.
	Build.box(self, Vector3(0.2, 1.4, 2.0), Vector3(-1.9, 1.2, -1.8), DARK)
	for i in 4:
		Build.wheel(self, 0.13, Vector3(-1.75, 1.0 + (i % 2) * 0.5, -2.4 + (i / 2) * 1.2), RED, Vector3.RIGHT)
	# Ladder up to the conning tower.
	var ladder := Ladder.new()
	ladder.name = "ladder_ct"
	add_child(ladder)
	var lz := HATCH.position.y - 0.02
	for side in [-0.25, 0.25]:
		Build.cyl(ladder, 0.03, CT_FLOOR, Vector3(side, CT_FLOOR * 0.5, lz), Color("#8A8F86"))
	for i in 8:
		Build.cyl(ladder, 0.02, 0.5, Vector3(0, 0.3 + i * 0.33, lz), Color("#8A8F86"), Vector3.RIGHT)
	Build.hitbox(ladder, Vector3(0.7, 2.4, 0.25), Vector3(0, 1.2, lz))
	var hz := HATCH.get_center().y
	ladder.top_y = CT_FLOOR
	ladder.bottom_path = [
		Vector3(0, 0.05, hz + 0.75), Vector3(0, 0.05, hz),
		Vector3(0, CT_FLOOR + 0.05, hz), Vector3(0, CT_FLOOR + 0.05, hz + 0.95),
	]
	# Railing round the hatch up top (part of the ladder so it is the "climb down" target).
	var r := HATCH
	var ry := CT_FLOOR + 0.45
	Build.box(ladder, Vector3(r.size.x + 0.1, 0.9, 0.05), Vector3(r.get_center().x, ry, r.position.y - 0.03), BRASS)
	Build.box(ladder, Vector3(r.size.x + 0.1, 0.9, 0.05), Vector3(r.get_center().x, ry, r.end.y + 0.03), BRASS)
	Build.box(ladder, Vector3(0.05, 0.9, r.size.y), Vector3(r.position.x - 0.03, ry, r.get_center().y), BRASS)
	Build.box(ladder, Vector3(0.05, 0.9, r.size.y), Vector3(r.end.x + 0.03, ry, r.get_center().y), BRASS)


func _conning_tower() -> void:
	var z0 := -6.5
	var z1 := -2.0
	var hw := 1.6
	var h := 2.3
	var mid := (z0 + z1) * 0.5
	var y := CT_FLOOR + h * 0.5
	for side in [-1.0, 1.0]:
		Build.box(self, Vector3(0.2, h, z1 - z0), Vector3(side * hw, y, mid), WALL)
	Build.box(self, Vector3(hw * 2.0, h, 0.2), Vector3(0, y, z0), WALL)
	Build.box(self, Vector3(hw * 2.0, h, 0.2), Vector3(0, y, z1), WALL)
	Build.box(self, Vector3(hw * 2.0, 0.2, z1 - z0), Vector3(0, CT_FLOOR + h + 0.1, mid), CEILING)
	var light := OmniLight3D.new()
	light.light_color = LIGHT
	light.light_energy = 1.1
	light.omni_range = 5.0
	light.position = Vector3(0, CT_FLOOR + h - 0.3, mid)
	add_child(light)
	Build.sphere(self, 0.08, Vector3(0, CT_FLOOR + h - 0.05, mid), LIGHT, 3.0)
	Build.label(self, "CONNING TOWER", Vector3(0, CT_FLOOR + h - 0.25, z0 + 0.13), 40, Color("#2B2B26"))
	_add_station(PeriscopeStation.new().setup("periscope", "Attack periscope"), Vector3(0, CT_FLOOR, -2.9))
	_gauge_board(Vector3(-0.8, CT_FLOOR + 1.7, z0 + 0.12), ["depth", "heading"])
	# Torpedo Data Computer cabinet (becomes a station in M3).
	Build.box(self, Vector3(0.5, 1.6, 1.3), Vector3(hw - 0.35, CT_FLOOR + 0.8, -4.3), Color("#4A5248"))
	Build.label(self, "TDC", Vector3(hw - 0.62, CT_FLOOR + 1.4, -4.3), 40).rotation.y = -PI / 2.0


func _engine_room() -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * 1.3
		Build.box(self, Vector3(1.1, 1.5, 9.0), Vector3(x, 0.75, 7.0), Color("#4E5550"))
		for i in 8:
			Build.box(self, Vector3(0.7, 0.25, 0.8), Vector3(x, 1.62, 3.2 + i * 1.08), Color("#6E756C"), false)
			Build.cyl(self, 0.05, 0.3, Vector3(x, 1.85, 3.2 + i * 1.08), BRASS)
		Build.cyl(self, 0.18, 9.0, Vector3(side * 1.55, 2.1, 7.0), Color("#3A3A3A"), Vector3.BACK)
	var rack := ToolRack.new()
	rack.position = Vector3(-1.97, 1.3, 1.3)
	rack.rotation.y = PI
	add_child(rack)
	Build.label(self, "DIESEL ENGINES — M3", Vector3(0, 1.9, 13.86), 36, Color("#2B2B26")).rotation.y = PI


func _gauge_board(pos: Vector3, kinds: Array) -> void:
	var board := Node3D.new()
	board.position = pos
	add_child(board)
	Build.box(board, Vector3(1.1, 0.25 * kinds.size() + 0.1, 0.04), Vector3.ZERO, Color("#151515"), false)
	for i in kinds.size():
		var l := Build.label(board, "", Vector3(0, (kinds.size() - 1) * 0.125 - i * 0.25, 0.03), 44, Color("#F2E8CF"))
		var kind: String = kinds[i]
		if not _gauges.has(kind):
			_gauges[kind] = []
		_gauges[kind].append(l)


## Which compartment each station sits in, for the hull damage model.
func station_compartments() -> Dictionary:
	var out := {}
	for sid: String in stations:
		var z: float = stations[sid].position.z
		for i in COMPARTMENTS.size():
			if z >= COMPARTMENTS[i].z0 and z < COMPARTMENTS[i].z1:
				out[sid] = i
	return out


## Lights stutter after a close depth charge.
func flicker(strength: float) -> void:
	_flicker = maxf(_flicker, strength)


func _process(delta: float) -> void:
	if Sim.world == null:
		return
	if _flicker > 0.0:
		_flicker = maxf(0.0, _flicker - delta * 0.8)
		for l in _lights:
			var on := _flicker == 0.0 or randf() > _flicker * 0.7
			l.light_energy = l.get_meta("energy") * (1.0 if on else 0.08)
	var sub := Sim.world.sub
	var text := {
		"depth": "DEPTH   %5.1f m" % sub.depth,
		"ordered": "ORDERED %5.0f m" % sub.ordered_depth,
		"speed": "SPEED   %5.1f kn" % (sub.speed / SubState.KNOT),
		"heading": "HEADING   %03d°" % (roundi(sub.heading) % 360),
	}
	for kind: String in _gauges:
		for l: Label3D in _gauges[kind]:
			l.text = text[kind]


## Apply host crew state: doors.
func apply_crew(crew: Dictionary) -> void:
	for id: String in crew.doors:
		if doors.has(id):
			doors[id].set_open(crew.doors[id])


func next_in_cluster(current: Station) -> Station:
	if current.cluster == "":
		return null
	var ids := stations.keys()
	var start := ids.find(current.station_id)
	for i in range(1, ids.size()):
		var s: Station = stations[ids[(start + i) % ids.size()]]
		if s.cluster == current.cluster and Game.instance.station_occupant(s.station_id) == 0:
			return s
	return null
