class_name SubInterior
extends Node3D
## A submarine's interior built from primitives for one sub class, from a layout of
## compartments fore to aft. Bow is -Z, the main deck floor is at y = 0, and the control
## room's after bulkhead is at z = 0 on every boat. Each compartment type knows its stations
## and fittings; the Gato and Narwhal have a conning tower over the control room (periscope
## and TDC), the S-boat runs helm, periscope, sonar and TDC from one control-room cluster.

const HALF_WIDTH := 2.0
const DECK_HEIGHT := 2.6
const CT_FLOOR := 2.8

const WALL := Color("#9DB59A")
const FLOOR := Color("#5E6B5C")
const CEILING := Color("#B5C4B0")
const BRASS := Color("#C9A04A")
const PIPE := Color("#D8D2C0")
const RED := Color("#B23A2E")
const DARK := Color("#3A3F38")
const LIGHT := Color("#FFD9A0")
const WOOD := Color("#6B5A44")
const BUNK := Color("#D8D2C0")

## Compartments fore to aft: {type, length (m)}. Names come from TITLES.
const LAYOUTS := {
	"s_boat": [
		{"type": "fwd_torpedo", "length": 11.0}, {"type": "battery", "length": 8.0},
		{"type": "control", "length": 9.0}, {"type": "engine", "length": 13.0},
	],
	"gato": [
		{"type": "fwd_torpedo", "length": 14.0}, {"type": "battery", "length": 8.0},
		{"type": "control", "length": 8.0}, {"type": "crew", "length": 8.0},
		{"type": "rec", "length": 6.0},
		{"type": "engine", "length": 14.0}, {"type": "maneuvering", "length": 6.0},
		{"type": "aft_torpedo", "length": 10.0},
	],
	"narwhal": [
		{"type": "fwd_torpedo", "length": 16.0}, {"type": "battery", "length": 9.0},
		{"type": "control", "length": 9.0}, {"type": "crew", "length": 9.0},
		{"type": "rec", "length": 6.0},
		{"type": "engine", "length": 12.0}, {"type": "engine2", "length": 12.0},
		{"type": "maneuvering", "length": 7.0}, {"type": "aft_torpedo", "length": 12.0},
	],
}
const TITLES := {
	"fwd_torpedo": "forward torpedo room", "battery": "officers' country / battery",
	"control": "control room", "crew": "crew's mess / stores", "rec": "rec room", "engine": "engine room",
	"engine2": "after engine room", "maneuvering": "maneuvering room", "aft_torpedo": "after torpedo room",
}

var sub_class: SubClassData
var compartments: Array[Dictionary] = [] ## {name, type, z0, z1}, as the hull model sees them
var door_links := {} ## door_id -> [comp_a, comp_b]
var stations := {} ## station_id -> Station, in build order
var doors := {} ## door_id -> WatertightDoor
var racks := {} ## compartment type -> damage control rack position (global)
var spawn_points: Array[Vector3] = []
var has_conning_tower := true
var damage: DamageView
var portholes: Array[Porthole] = []
var _gauges := {} ## kind -> Array[Label3D]
var _lights: Array[OmniLight3D] = []
var _flicker := 0.0
var _rockers: Array[Array] = [[], []] ## per diesel (port, starboard): cylinder-head covers
var _next_tube := 0
var _diesel_sound: AudioStreamPlayer3D
var _motor_sound: AudioStreamPlayer3D
var _creak_timer := 5.0
var _vents_were := false


static func create(data: SubClassData) -> SubInterior:
	var i := SubInterior.new()
	i.sub_class = data
	i.name = "Interior"
	i.has_conning_tower = data.key != "s_boat"
	var layout: Array = LAYOUTS.get(data.key, LAYOUTS.gato)
	# Lay the compartments out so the control room ends at z = 0.
	var z := 0.0
	var ci := 0
	for k in layout.size():
		if layout[k].type == "control":
			ci = k
	for k in range(ci, -1, -1):
		z -= float(layout[k].length)
	for c: Dictionary in layout:
		i.compartments.append({"name": TITLES[c.type], "type": c.type, "z0": z, "z1": z + float(c.length)})
		z += float(c.length)
	for k in layout.size() - 1:
		i.door_links["d%d" % k] = [k, k + 1]
	return i


func comp_index(type: String) -> int:
	for k in compartments.size():
		if compartments[k].type == type:
			return k
	return -1


func comp(type: String) -> Dictionary:
	var k := comp_index(type)
	return compartments[k] if k >= 0 else {}


func _ready() -> void:
	build()


## Builds everything (done on entering the tree; tests call it directly).
func build() -> void:
	if not stations.is_empty():
		return
	_build_environment()
	var ct := comp("control")
	var hatch := Rect2(-0.45, ct.z0 + 3.0, 0.9, 0.9) if has_conning_tower else Rect2()
	for k in compartments.size():
		var c := compartments[k]
		_compartment(c.z0, c.z1, c.name.to_upper(), hatch if c.type == "control" else Rect2())
		_bulkhead(c.z0, "d%d" % (k - 1) if k > 0 else "")
	_bulkhead(compartments[-1].z1, "")
	for c in compartments:
		match c.type:
			"fwd_torpedo":
				_torpedo_room(c, false)
			"aft_torpedo":
				_torpedo_room(c, true)
			"battery":
				_battery(c)
			"control":
				_control_room(c, hatch)
			"crew":
				_crew(c)
			"rec":
				_rec_room(c)
			"engine", "engine2":
				_engine_room(c, c.type == "engine")
			"maneuvering":
				_maneuvering(c)
	_air_and_stores()
	_portholes()
	if has_conning_tower:
		_conning_tower(ct, hatch)
	damage = DamageView.new()
	damage.name = "Damage"
	damage.interior = self
	add_child(damage)
	for l in find_children("*", "OmniLight3D", true, false):
		_lights.append(l)
		l.set_meta("energy", l.light_energy)
	var er := comp("engine")
	_diesel_sound = Sfx.loop_at(self, "diesel_loop", Vector3(0, 1.0, (er.z0 + er.z1) * 0.5), -80.0, 8.0)
	var mr := comp("maneuvering") if comp_index("maneuvering") >= 0 else er
	_motor_sound = Sfx.loop_at(self, "motor_loop", Vector3(0, 1.0, (mr.z0 + mr.z1) * 0.5), -80.0, 10.0)
	for i in 6:
		spawn_points.append(Vector3(-0.6 + (i % 3) * 0.6, 0.1, ct.z1 - 2.6 - (i / 3) * 0.7))


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


## A damage control rack on the starboard wall (port when `port`), `z` along the hull.
func _rack(type: String, z: float, port := false) -> void:
	var rack := ToolRack.new()
	rack.position = Vector3(-1.97 if port else 1.97, 1.3, z)
	if port:
		rack.rotation.y = PI
	add_child(rack)
	racks[type] = rack.position + Vector3(-0.1 if not port else 0.1, 1.1, 0)


func _bunks(z0: float, z1: float, sides := [-1.0, 1.0]) -> void:
	for side: float in sides:
		for y in [0.5, 1.3]:
			Build.box(self, Vector3(0.75, 0.08, z1 - z0), Vector3(side * 1.55, y, (z0 + z1) * 0.5), WOOD)
			Build.box(self, Vector3(0.7, 0.12, z1 - z0 - 0.2), Vector3(side * 1.55, y + 0.1, (z0 + z1) * 0.5), BUNK, false)


## Portholes: over the wardroom table and the officers' bunks, and either side of the mess
## table (lando, Blaney: windows to look out of).
func _portholes() -> void:
	var spots: Array = []
	if comp_index("battery") >= 0:
		var b := comp("battery")
		spots.append([Vector3(HALF_WIDTH - 0.02, 1.6, (b.z0 + b.z1) * 0.5), 1.0])
		spots.append([Vector3(-HALF_WIDTH + 0.02, 1.85, (b.z0 + b.z1) * 0.5 - 1.0), -1.0])
	if comp_index("crew") >= 0:
		var c := comp("crew")
		spots.append([Vector3(HALF_WIDTH - 0.02, 1.6, c.z1 - 1.2), 1.0])
		spots.append([Vector3(-HALF_WIDTH + 0.02, 1.6, c.z1 - 1.2), -1.0])
	for s: Array in spots:
		var p := Porthole.create(s[0], s[1])
		add_child(p)
		portholes.append(p)


# --- Compartments ----------------------------------------------------------

func _torpedo_room(c: Dictionary, aft: bool) -> void:
	var count := sub_class.stern_tubes if aft else sub_class.bow_tubes
	var wall_z: float = c.z1 - 0.1 if aft else c.z0 + 0.1
	for i in count:
		var tube := TorpedoTubeStation.new()
		tube.tube_index = _next_tube
		tube.stern = aft
		_next_tube += 1
		tube.setup("tube_%d" % _next_tube, "Torpedo tube %d" % _next_tube, "aft_tubes" if aft else "tubes")
		var x := 0.65 if i % 2 == 0 else -0.65
		if aft:
			x = -x
		var y := 1.95 - (i / 2) * 0.7
		_add_station(tube, Vector3(x, y, wall_z), PI if aft else 0.0)
	# Reload torpedoes on racks along both sides, bunks above them.
	var rz0: float = c.z0 + (2.5 if aft else 3.0)
	var rz1: float = c.z1 - (3.0 if aft else 2.5)
	for side in [-1.0, 1.0]:
		for y in [0.45, 1.05]:
			var t := Build.cyl(self, 0.27, rz1 - rz0, Vector3(side * 1.5, y, (rz0 + rz1) * 0.5), Color("#5D6B4E"), Vector3.BACK, true)
			Build.sphere(t, 0.27, Vector3(0, (rz1 - rz0) * 0.5 * (1.0 if aft else -1.0) * -1.0, 0), Color("#5D6B4E"))
		Build.box(self, Vector3(0.75, 0.08, rz1 - rz0), Vector3(side * 1.55, 1.75, (rz0 + rz1) * 0.5), WOOD)
		Build.box(self, Vector3(0.7, 0.12, rz1 - rz0 - 0.2), Vector3(side * 1.55, 1.85, (rz0 + rz1) * 0.5), BUNK, false)
	_rack(c.type, c.z0 + 1.4 if aft else c.z1 - 1.4)
	# Chain hoist rail down the centre for moving torpedoes.
	Build.box(self, Vector3(0.12, 0.12, c.z1 - c.z0 - 2.0), Vector3(0, DECK_HEIGHT - 0.2, (c.z0 + c.z1) * 0.5), DARK, false)


func _battery(c: Dictionary) -> void:
	# Officers' staterooms to port, wardroom table to starboard, battery well hatches underfoot.
	_bunks(c.z0 + 0.8, c.z1 - 3.0, [-1.0])
	Build.box(self, Vector3(1.0, 0.8, 2.2), Vector3(1.35, 0.4, (c.z0 + c.z1) * 0.5), WOOD)
	Build.box(self, Vector3(1.1, 0.04, 2.3), Vector3(1.35, 0.82, (c.z0 + c.z1) * 0.5), Color("#E8DFC4"), false)
	for z in [c.z0 + 2.0, c.z1 - 2.0]:
		Build.box(self, Vector3(0.9, 0.03, 0.9), Vector3(0, 0.02, z), DARK, false)
		Build.box(self, Vector3(0.3, 0.04, 0.05), Vector3(0, 0.05, z), BRASS, false)
	Build.label(self, "BATTERY WELL", Vector3(0, 0.06, c.z0 + 2.0), 22, Color("#C9A04A")).rotation.x = -PI / 2.0
	_rack(c.type, c.z1 - 1.4)


func _control_room(c: Dictionary, hatch: Rect2) -> void:
	var z0: float = c.z0
	var z1: float = c.z1
	# Planes and ballast to port, helm to starboard; sonar and chart further aft.
	var cl := "conn" if not has_conning_tower else "helm_dive"
	_add_station(DiveStation.new().setup("dive", "Dive planes", "helm_dive"), Vector3(-1.85, 0, z0 + 2.0))
	_add_station(HelmStation.new().setup("helm", "Helm", cl), Vector3(1.8, 0, z0 + 2.0))
	_gauge_board(Vector3(-1.25, 1.7, z0 + 0.12), ["depth", "ordered"])
	_gauge_board(Vector3(1.25, 1.7, z0 + 0.12), ["speed", "heading", "battery"])
	_add_station(SonarStation.new().setup("sonar", "Sonar", "conn" if not has_conning_tower else ""), Vector3(-1.85, 0, z0 + 4.3))
	_add_station(BallastStation.new().setup("ballast", "Ballast manifold"), Vector3(-1.85, 0, z1 - 1.8))
	_add_station(NavStation.new().setup("nav", "Chart table"), Vector3(1.4, 0, z1 - 1.6))
	if not has_conning_tower:
		# S-boat: the periscope comes down into the control room and the TDC sits by the helm.
		_add_station(PeriscopeStation.new().setup("periscope", "Periscope", "conn"), Vector3(0, 0, z0 + 4.6))
		_add_station(TdcStation.new().setup("tdc", "Torpedo Data Computer", "conn"), Vector3(1.55, 0, z0 + 3.6))
		_rack(c.type, z0 + 5.4)
		return
	_rack(c.type, z0 + 4.4)
	# Ladder up to the conning tower.
	var ladder := Ladder.new()
	ladder.name = "ladder_ct"
	add_child(ladder)
	var lz := hatch.position.y - 0.02
	for side in [-0.25, 0.25]:
		Build.cyl(ladder, 0.03, CT_FLOOR, Vector3(side, CT_FLOOR * 0.5, lz), Color("#8A8F86"))
	for i in 8:
		Build.cyl(ladder, 0.02, 0.5, Vector3(0, 0.3 + i * 0.33, lz), Color("#8A8F86"), Vector3.RIGHT)
	Build.hitbox(ladder, Vector3(0.7, 2.4, 0.25), Vector3(0, 1.2, lz))
	var hz := hatch.get_center().y
	ladder.top_y = CT_FLOOR
	ladder.bottom_path = [
		Vector3(0, 0.05, hz + 0.75), Vector3(0, 0.05, hz),
		Vector3(0, CT_FLOOR + 0.05, hz), Vector3(0, CT_FLOOR + 0.05, hz + 0.95),
	]
	# Railing round the hatch up top (part of the ladder so it is the "climb down" target).
	var r := hatch
	var ry := CT_FLOOR + 0.45
	Build.box(ladder, Vector3(r.size.x + 0.1, 0.9, 0.05), Vector3(r.get_center().x, ry, r.position.y - 0.03), BRASS)
	Build.box(ladder, Vector3(r.size.x + 0.1, 0.9, 0.05), Vector3(r.get_center().x, ry, r.end.y + 0.03), BRASS)
	Build.box(ladder, Vector3(0.05, 0.9, r.size.y), Vector3(r.position.x - 0.03, ry, r.get_center().y), BRASS)
	Build.box(ladder, Vector3(0.05, 0.9, r.size.y), Vector3(r.end.x + 0.03, ry, r.get_center().y), BRASS)


func _conning_tower(c: Dictionary, hatch: Rect2) -> void:
	var z0: float = c.z0 + 1.5
	var z1: float = c.z1 - 2.0
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
	_add_station(PeriscopeStation.new().setup("periscope", "Attack periscope", "attack"), Vector3(0, CT_FLOOR, z1 - 0.9))
	_gauge_board(Vector3(-0.8, CT_FLOOR + 1.7, z0 + 0.12), ["depth", "heading"])
	_add_station(TdcStation.new().setup("tdc", "Torpedo Data Computer", "attack"), Vector3(hw - 0.45, CT_FLOOR, z0 + 2.2))


func _crew(c: Dictionary) -> void:
	# Forward: air panel (starboard) and rack (port); bunks amidships; mess table and stores aft.
	_rack(c.type, c.z0 + 1.3, true)
	_bunks(c.z0 + 2.5, c.z1 - 2.5)
	Build.box(self, Vector3(0.9, 0.75, 1.8), Vector3(1.3, 0.38, c.z1 - 1.2), WOOD)
	Build.box(self, Vector3(1.0, 0.04, 1.9), Vector3(1.3, 0.77, c.z1 - 1.2), Color("#E8DFC4"), false)


## The rec room (lando: whimsical fun and mini games, apart from the patrol): a dartboard on
## the after bulkhead with a chalkboard of best turns, a jukebox, a card table, portholes.
func _rec_room(c: Dictionary) -> void:
	# The board on the starboard wall amidships (the bulkheads have doors); the oche across the room.
	var mid: float = (c.z0 + c.z1) * 0.5
	_add_station(DartsStation.new().setup("darts", "Darts"), Vector3(HALF_WIDTH - 0.06 - DartsStation.OCHE, 0, mid), -PI / 2.0)
	var jb := Jukebox.new()
	jb.position = Vector3(-1.45, 0, c.z0 + 0.6)
	jb.rotation.y = PI
	add_child(jb)
	Build.box(self, Vector3(0.9, 0.72, 0.9), Vector3(1.3, 0.36, c.z0 + 1.4), WOOD) # card table
	Build.box(self, Vector3(1.0, 0.04, 1.0), Vector3(1.3, 0.74, c.z0 + 1.4), Color("#2B6A3A"), false) # baize
	for k in 5:
		var card := Build.box(self, Vector3(0.06, 0.005, 0.09), Vector3(1.15 + k * 0.07, 0.765, c.z0 + 1.35 + (k % 2) * 0.05), Color("#F2F0E8"), false)
		card.rotation.y = k * 0.3
	var p := Porthole.create(Vector3(-HALF_WIDTH + 0.02, 1.6, (c.z0 + c.z1) * 0.5), -1.0)
	add_child(p)
	portholes.append(p)


func _engine_room(c: Dictionary, controls: bool) -> void:
	var z0: float = c.z0
	var z1: float = c.z1
	var eng_z0 := z0 + 2.5
	var eng_z1 := z1 - 2.6
	for side in [-1.0, 1.0]:
		var x: float = side * 1.3
		Build.box(self, Vector3(1.1, 1.5, eng_z1 - eng_z0), Vector3(x, 0.75, (eng_z0 + eng_z1) * 0.5), Color("#4E5550"))
		var n := int((eng_z1 - eng_z0) / 1.08)
		for i in n:
			var rocker := Build.box(self, Vector3(0.7, 0.25, 0.8), Vector3(x, 1.62, eng_z0 + 0.7 + i * 1.08), Color("#6E756C"), false)
			Build.cyl(self, 0.05, 0.3, Vector3(x, 1.85, eng_z0 + 0.7 + i * 1.08), BRASS)
			rocker.set_meta("y", rocker.position.y)
			_rockers[0 if side < 0.0 else 1].append(rocker)
		Build.cyl(self, 0.18, eng_z1 - eng_z0, Vector3(side * 1.55, 2.1, (eng_z0 + eng_z1) * 0.5), Color("#3A3A3A"), Vector3.BACK)
	_rack(c.type, z0 + 1.3, true)
	if controls:
		_add_station(EngineStation.new().setup("engine", "Diesel controls"), Vector3(0, 0, z1 - 0.25), -PI / 2.0)


func _maneuvering(c: Dictionary) -> void:
	# The electrical control cubicle: rows of switch panels both sides.
	var cz0: float = c.z0 + 1.6
	var cz1: float = c.z1 - 0.4
	for side in [-1.0, 1.0]:
		Build.box(self, Vector3(0.4, 1.8, cz1 - cz0), Vector3(side * 1.75, 0.9, (cz0 + cz1) * 0.5), DARK)
		for i in 4:
			Build.box(self, Vector3(0.04, 0.12, 0.06), Vector3(side * 1.53, 1.0 + (i % 2) * 0.4, cz0 + 0.4 + i * 0.8), BRASS, false)
	_rack(c.type, c.z0 + 0.8)


## The air panel and the spare-parts stores live in the first compartment aft of the control
## room on every boat (crew's mess, or the S-boat's engine room).
func _air_and_stores() -> void:
	var k := comp_index("control") + 1
	var c: Dictionary = compartments[mini(k, compartments.size() - 1)]
	_add_station(AirStation.new().setup("air", "Air panel"), Vector3(1.8, 0, c.z0 + 1.3))
	var crate := PartsCrate.new()
	crate.position = Vector3(-1.35, 0, c.z1 - 1.1)
	add_child(crate)


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
		for i in compartments.size():
			if z >= compartments[i].z0 and z < compartments[i].z1:
				out[sid] = i
	return out


## A close blast shakes paint flakes and dust down from the deckhead all through the boat.
func shake_loose(strength: float) -> void:
	for c in compartments:
		var p := Build.particles(self, Color(0.45, 0.5, 0.42, 0.8), int(10 + 30 * strength), 1.6, Vector3.DOWN, 0.5, 40.0, Vector3(0, -6, 0), 0.018)
		p.position = Vector3(0, DECK_HEIGHT - 0.1, (c.z0 + c.z1) * 0.5)
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(HALF_WIDTH - 0.3, 0.05, (c.z1 - c.z0) * 0.5 - 0.3)
		p.one_shot = true
		p.explosiveness = 0.7
		p.emitting = true
		get_tree().create_timer(3.0).timeout.connect(p.queue_free)


## Lights stutter after a close depth charge.
func flicker(strength: float) -> void:
	_flicker = maxf(_flicker, strength)


func _process(delta: float) -> void:
	if Sim.world == null:
		return
	var sub := Sim.world.sub
	# Lights brown out as the battery runs down, unless the diesels carry the load.
	var power := 1.0 if sub.diesels_running() > 0 else lerpf(0.3, 1.0, clampf(sub.battery / 0.15, 0.0, 1.0))
	_flicker = maxf(0.0, _flicker - delta * 0.8)
	# Rig for red: at night, submerged, the boat runs on red light so eyes stay dark-adapted.
	var red := Sim.world.conditions.night and not sub.is_surfaced()
	for l in _lights:
		var on := _flicker == 0.0 or randf() > _flicker * 0.7
		l.light_energy = l.get_meta("energy") * power * (1.0 if on else 0.08) * (0.8 if red else 1.0)
		l.light_color = Color("#FF4A35") if red else LIGHT
	for i in _rockers.size():
		var shake := 0.012 if sub.diesels[i] >= 1.0 else (0.006 if sub.diesels[i] > 0.0 else 0.0)
		for r: MeshInstance3D in _rockers[i]:
			r.position.y = r.get_meta("y") + randf_range(-shake, shake)
	_sounds(sub, delta)
	var text := {
		"depth": "DEPTH   %5.1f m" % sub.depth,
		"ordered": "ORDERED %5.0f m" % sub.ordered_depth,
		"speed": "SPEED   %5.1f kn" % (sub.speed / SubState.KNOT),
		"heading": "HEADING   %03d°" % (roundi(sub.heading) % 360),
		"battery": "BATTERY   %3d%%" % roundi(sub.battery * 100.0),
	}
	for kind: String in _gauges:
		for l: Label3D in _gauges[kind]:
			l.text = text[kind]


## The boat's own noises: diesels thudding in the engine room, the motors whirring aft (soft
## at slow speed, louder flat out),
## the hull creaking deeper down (a lot past test depth), the klaxon when the vents open.
func _sounds(sub: SubState, delta: float) -> void:
	if _diesel_sound == null:
		return
	var running := sub.diesels_running()
	_diesel_sound.volume_db = -80.0 if running == 0 else (-4.0 if running == 2 else -9.0)
	var on_motors := running == 0 and absf(sub.speed) > 0.1
	var flank := clampf(absf(sub.speed) / (sub.data.submerged_speed_kn * SubState.KNOT), 0.0, 1.0)
	_motor_sound.volume_db = linear_to_db(lerpf(0.12, 1.0, flank * flank)) - 10.0 if on_motors else -80.0
	_motor_sound.pitch_scale = 0.85 + 0.3 * flank
	if sub.vents_open and not _vents_were:
		Sfx.play("klaxon")
	_vents_were = sub.vents_open
	_creak_timer -= delta
	if _creak_timer <= 0.0:
		var deep := sub.depth / float(sub.data.test_depth)
		_creak_timer = randf_range(6.0, 14.0) / maxf(0.2, deep * deep)
		if deep > 0.4:
			var c: Dictionary = compartments[randi() % compartments.size()]
			Sfx.play_at(self, "creak_%d" % randi_range(1, 3), Vector3(randf_range(-1.8, 1.8), 2.0, randf_range(c.z0, c.z1)),
				lerpf(-14.0, 0.0, clampf(deep - 0.4, 0.0, 1.0)), randf_range(0.8, 1.1))


## Apply host crew state: doors.
func apply_crew(crew: Dictionary) -> void:
	for id: String in crew.doors:
		if doors.has(id):
			doors[id].set_open(crew.doors[id])
	_sync_bots(crew.get("bots", {}))


var _bot_views := {} ## station id -> BotView


## A BotView at each station a bot crewman has, from crew state.
func _sync_bots(bots: Dictionary) -> void:
	for sid: String in bots:
		if not stations.has(sid):
			continue
		if not _bot_views.has(sid):
			var v := BotView.create(stations[sid], bots[sid])
			add_child(v)
			_bot_views[sid] = v
		else:
			(_bot_views[sid] as BotView).refresh(bots[sid])
	for sid: String in _bot_views.keys():
		if not bots.has(sid):
			_bot_views[sid].queue_free()
			_bot_views.erase(sid)


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
