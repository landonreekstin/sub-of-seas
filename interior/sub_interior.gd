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
const SHOULDER_R := 0.75 ## radius of the curved hull between wall and deckhead
const VIEW_HOPS := 2 ## rooms beyond this one that are drawn, through open doors

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
		{"type": "control", "length": 9.0}, {"type": "nav", "length": 5.0}, {"type": "berthing", "length": 6.0},
		{"type": "engine", "length": 13.0},
	],
	"gato": [
		{"type": "fwd_torpedo", "length": 14.0}, {"type": "battery", "length": 8.0},
		{"type": "control", "length": 8.0}, {"type": "nav", "length": 6.0}, {"type": "crew", "length": 8.0},
		{"type": "berthing", "length": 6.0}, {"type": "rec", "length": 6.0},
		{"type": "engine", "length": 14.0}, {"type": "maneuvering", "length": 6.0},
		{"type": "aft_torpedo", "length": 10.0},
	],
	"narwhal": [
		{"type": "fwd_torpedo", "length": 16.0}, {"type": "battery", "length": 9.0},
		{"type": "control", "length": 9.0}, {"type": "nav", "length": 6.0}, {"type": "crew", "length": 9.0},
		{"type": "berthing", "length": 7.0}, {"type": "rec", "length": 6.0},
		{"type": "engine", "length": 12.0}, {"type": "engine2", "length": 12.0},
		{"type": "maneuvering", "length": 7.0}, {"type": "aft_torpedo", "length": 12.0},
	],
}
const TITLES := {
	"fwd_torpedo": "forward torpedo room", "battery": "wardroom / battery",
	"control": "control room", "nav": "navigation room", "crew": "crew's mess / stores", "berthing": "crew's quarters", "rec": "rec room", "engine": "engine room",
	"engine2": "after engine room", "maneuvering": "maneuvering room", "aft_torpedo": "after torpedo room",
}

var sub_class: SubClassData
var compartments: Array[Dictionary] = [] ## {name, type, z0, z1}, as the hull model sees them
var door_links := {} ## door_id -> [comp_a, comp_b]
var stations := {} ## station_id -> Station, in build order
var doors := {} ## door_id -> WatertightDoor
var _muffle_timer := 0.0
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
var _rain_sound: AudioStreamPlayer3D
var _creak_timer := 5.0
var _vents_were := false
var _at: Node3D = self ## what's being built goes on this: the boat, or on a Typhoon its room (TyphoonLayout)
var _rooms: Array[Node3D] = [] ## Typhoon: each compartment's root, so rooms out of sight can be hidden
var _room_links: Array = [] ## Typhoon: [door id or "", comp a, comp b]
var main_ladder: Ladder ## the ladder between decks, for the damage parties
var _cull_timer := 0.0
var _env: Environment
const TYPHOON_LIGHT := Color("#D6E6FF") ## the Typhoon's cold blue-white strip lights, as in the film
const BATTLE_RED := Color("#FF3A2A")


static func create(data: SubClassData) -> SubInterior:
	var i := SubInterior.new()
	i.sub_class = data
	i.name = "Interior"
	i.has_conning_tower = data.key != "s_boat"
	if data.key == "typhoon":
		i.has_conning_tower = false
		TyphoonLayout.lay_out(i)
		return i
	if data.key == "titan":
		TitanLayout.lay_out(i)
		return i
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
	if sub_class.key == "titan":
		TitanLayout.build(self)
		_finish_build()
		return
	if sub_class.key == "typhoon":
		Build.recolor = TYPHOON_PAINT
		TyphoonLayout.build(self)
		Build.recolor = {}
		_finish_build()
		return
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
			"berthing":
				_berthing(c)
			"rec":
				_rec_room(c)
			"nav":
				_nav_room(c)
			"engine", "engine2":
				_engine_room(c, c.type == "engine")
			"maneuvering":
				_maneuvering(c)
	_air_and_stores()
	_portholes()
	if has_conning_tower:
		_conning_tower(ct, hatch)
	for c in compartments:
		_dressing(c, hatch if c.type == "control" else Rect2())
		_clutter(c, [])
	_wwii_control_gear(ct)
	_finish_build()
	var er := comp("engine")
	_diesel_sound = Sfx.loop_at(self, "diesel_loop", Vector3(0, 1.0, (er.z0 + er.z1) * 0.5), -80.0, 8.0)
	var mr := comp("maneuvering") if comp_index("maneuvering") >= 0 else er
	_motor_sound = Sfx.loop_at(self, "motor_loop", Vector3(0, 1.0, (mr.z0 + mr.z1) * 0.5), -80.0, 10.0)
	_rain_sound = Sfx.loop_at(self, "rain_loop", Vector3(0, DECK_HEIGHT, (ct.z0 + ct.z1) * 0.5), -80.0, 30.0)
	for i in 6:
		spawn_points.append(Vector3(-0.6 + (i % 3) * 0.6, 0.1, ct.z1 - 2.6 - (i / 3) * 0.7))


func _finish_build() -> void:
	damage = DamageView.new()
	damage.name = "Damage"
	damage.interior = self
	add_child(damage)
	for l in find_children("*", "OmniLight3D", true, false):
		_lights.append(l)
		l.set_meta("energy", l.light_energy)


func _build_environment() -> void:
	var env := Environment.new()
	_env = env
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

## `gaps` are door openings in the side walls: [side (-1 port, 1 starboard), z of the door].
func _compartment(z0: float, z1: float, title: String, ceiling_hole := Rect2(), gaps: Array = [], floor_hole := Rect2()) -> void:
	var length := z1 - z0
	var mid := (z0 + z1) * 0.5
	_slab(-0.1, z0, z1, floor_hole, FLOOR)
	for side in [-1.0, 1.0]:
		var from := z0
		var pieces: Array = []
		var here := gaps.filter(func(g: Array) -> bool: return g[0] == side)
		here.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
		for g: Array in here:
			pieces.append([from, float(g[1]) - WatertightDoor.WIDTH * 0.5])
			from = float(g[1]) + WatertightDoor.WIDTH * 0.5
		pieces.append([from, z1])
		for piece: Array in pieces:
			var a: float = piece[0]
			var b: float = piece[1]
			Build.box(_at, Vector3(0.2, DECK_HEIGHT + 0.2, b - a), Vector3(side * (HALF_WIDTH + 0.1), DECK_HEIGHT * 0.5, (a + b) * 0.5), WALL)
			# Curved shoulders and bilges make the box read as a round pressure hull.
			Build.arc(_at, Vector2(side * (HALF_WIDTH - 0.4), 0.4), 0.4,
					-PI * 0.5 if side > 0.0 else PI, 0.0 if side > 0.0 else PI * 1.5, 0.12, a, b, FLOOR, 6)
		for g: Array in here: # the wall over each door
			Build.box(_at, Vector3(0.2, DECK_HEIGHT - WatertightDoor.HEIGHT + 0.1, WatertightDoor.WIDTH), Vector3(side * (HALF_WIDTH + 0.1), (DECK_HEIGHT + WatertightDoor.HEIGHT) * 0.5, g[1]), WALL)
		Build.arc(_at, Vector2(side * (HALF_WIDTH - SHOULDER_R), DECK_HEIGHT - SHOULDER_R), SHOULDER_R,
				0.0 if side > 0.0 else PI * 0.5, PI * 0.5 if side > 0.0 else PI, 0.12, z0, z1, WALL)
		# Pipe runs.
		Build.cyl(_at, 0.05, length, Vector3(side * 1.35, DECK_HEIGHT - 0.12, mid), BRASS, Vector3.BACK)
		Build.cyl(_at, 0.08, length, Vector3(side * 1.1, DECK_HEIGHT - 0.1, mid), PIPE, Vector3.BACK)
	_slab(DECK_HEIGHT + 0.1, z0, z1, ceiling_hole, CEILING)
	# Lights: a warm bulb every few metres.
	var n := maxi(1, roundi(length / 5.0))
	for i in n:
		var z := z0 + length * (i + 0.5) / n
		Build.sphere(_at, 0.08, Vector3(0, DECK_HEIGHT - 0.05, z), LIGHT, 3.0)
	# The Typhoon's long rooms need more than one lamp to reach.
	var lamps := roundi(length / 14.0) if length > 30.0 else 1
	for i in lamps:
		var light := OmniLight3D.new()
		light.light_color = LIGHT
		light.light_energy = 1.2 if lamps > 1 else 1.4
		light.omni_range = 12.0 if lamps > 1 else maxf(7.0, length * 0.75)
		light.position = Vector3(0, DECK_HEIGHT - 0.3, z0 + length * (i + 0.5) / lamps)
		_at.add_child(light)
	# Label3D reads from +Z: the aft-wall sign turns to face forward.
	Build.label(_at, title, Vector3(0, DECK_HEIGHT - 0.25, z1 - 0.13), 40, Color("#2B2B26")).rotation.y = PI
	Build.label(_at, title, Vector3(0, DECK_HEIGHT - 0.25, z0 + 0.13), 40, Color("#2B2B26"))


## A horizontal slab at height `y` spanning the hull width, with an optional hole.
func _slab(y: float, z0: float, z1: float, hole: Rect2, color: Color) -> void:
	var w := HALF_WIDTH * 2.0 + 0.4
	if hole.size == Vector2.ZERO:
		Build.box(_at, Vector3(w, 0.2, z1 - z0), Vector3(0, y, (z0 + z1) * 0.5), color)
		return
	var hx0 := hole.position.x
	var hx1 := hole.end.x
	var hz0 := hole.position.y
	var hz1 := hole.end.y
	Build.box(_at, Vector3(w, 0.2, hz0 - z0), Vector3(0, y, (z0 + hz0) * 0.5), color)
	Build.box(_at, Vector3(w, 0.2, z1 - hz1), Vector3(0, y, (hz1 + z1) * 0.5), color)
	var lw := hx0 + w * 0.5
	Build.box(_at, Vector3(lw, 0.2, hz1 - hz0), Vector3(-w * 0.5 + lw * 0.5, y, (hz0 + hz1) * 0.5), color)
	var rw := w * 0.5 - hx1
	Build.box(_at, Vector3(rw, 0.2, hz1 - hz0), Vector3(hx1 + rw * 0.5, y, (hz0 + hz1) * 0.5), color)


func _bulkhead(z: float, door_id: String) -> void:
	var h := DECK_HEIGHT + 0.2
	if door_id == "":
		Build.box(_at, Vector3(HALF_WIDTH * 2.0, h, 0.2), Vector3(0, h * 0.5 - 0.1, z), WALL)
		return
	var dw := WatertightDoor.WIDTH * 0.5
	var side_w := HALF_WIDTH - dw
	for side in [-1.0, 1.0]:
		Build.box(_at, Vector3(side_w, h, 0.2), Vector3(side * (dw + side_w * 0.5), h * 0.5 - 0.1, z), WALL)
	var top_h := h - WatertightDoor.HEIGHT
	Build.box(_at, Vector3(dw * 2.0, top_h, 0.2), Vector3(0, WatertightDoor.HEIGHT + top_h * 0.5 - 0.1, z), WALL)
	var door := WatertightDoor.new().setup(door_id)
	door.position = Vector3(0, 0, z)
	_at.add_child(door)
	doors[door_id] = door


func _add_station(s: Station, pos: Vector3, rot_y := 0.0) -> Station:
	s.position = pos
	s.rotation.y = rot_y
	_at.add_child(s)
	stations[s.station_id] = s
	return s


## A damage control rack on the starboard wall (port when `port`), `z` along the hull.
func _rack(type: String, z: float, port := false) -> void:
	var rack := ToolRack.new()
	rack.position = Vector3(-1.97 if port else 1.97, 1.3, z)
	if port:
		rack.rotation.y = PI
	_at.add_child(rack)
	racks[type] = rack.position + Vector3(-0.1 if not port else 0.1, 1.1, 0)


## Portholes: over the wardroom table and across from it, and either side of the mess table
## (lando, Blaney: windows to look out of).
func _portholes() -> void:
	var spots: Array = []
	if comp_index("battery") >= 0:
		var b := comp("battery")
		spots.append([Vector3(HALF_WIDTH - 0.02, 1.6, (b.z0 + b.z1) * 0.5), 1.0])
		spots.append([Vector3(-HALF_WIDTH + 0.02, 1.6, (b.z0 + b.z1) * 0.5 - 1.0), -1.0])
	if comp_index("crew") >= 0:
		var c := comp("crew")
		spots.append([Vector3(HALF_WIDTH - 0.02, 1.6, c.z1 - 1.2), 1.0])
		spots.append([Vector3(-HALF_WIDTH + 0.02, 1.6, c.z1 - 1.2), -1.0])
	for s: Array in spots:
		var p := Porthole.create(s[0], s[1])
		_at.add_child(p)
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
	if not aft: # the escape trunk overhead, aft of the tubes (Blaney: out of the sub while dived)
		var trunk := EscapeTrunk.new()
		trunk.position = Vector3(0, 0, c.z0 + 2.2)
		_at.add_child(trunk)
	# Reload torpedoes on racks along both sides.
	var rz0: float = c.z0 + (2.5 if aft else 3.0)
	var rz1: float = c.z1 - (3.0 if aft else 2.5)
	for side in [-1.0, 1.0]:
		for y in [0.45, 1.05]:
			Build.torpedo(_at, 0.27, minf(rz1 - rz0, 6.4), Vector3(side * 1.5, y, (rz0 + rz1) * 0.5), aft)
			Build.box(_at, Vector3(0.54, 0.54, rz1 - rz0), Vector3(side * 1.5, y, (rz0 + rz1) * 0.5), DARK).visible = false
			for k in 3: # the rack's cradle straps
				var cz := lerpf(rz0 + 0.8, rz1 - 0.8, k / 2.0)
				Build.arc(_at, Vector2(side * 1.5, y), 0.275, PI * 1.05, PI * 1.95, 0.025, cz - 0.04, cz + 0.04, DARK, 8)
	_rack(c.type, c.z0 + 1.4 if aft else c.z1 - 1.4)
	Living.torpedo_bunks(self, rz0, rz1)
	Living.picture(self, Vector3(1.35, 1.5, c.z0 + 0.12 if aft else c.z1 - 0.12), 0.0 if aft else PI, "pinup", _next_tube)
	# Chain hoist rail down the centre for moving torpedoes.
	Build.box(_at, Vector3(0.12, 0.12, c.z1 - c.z0 - 2.0), Vector3(0, DECK_HEIGHT - 0.2, (c.z0 + c.z1) * 0.5), DARK, false)


func _battery(c: Dictionary) -> void:
	# A locker bank to port, wardroom table to starboard, battery well hatches underfoot.
	var lz0: float = c.z0 + 0.8
	var lockers := int(c.z1 - 3.0 - lz0)
	for k in lockers:
		Build.box(_at, Vector3(0.5, 1.15, 0.92), Vector3(-HALF_WIDTH + 0.3, 0.575, lz0 + k + 0.5), WOOD)
		Build.box(_at, Vector3(0.02, 0.1, 0.03), Vector3(-HALF_WIDTH + 0.56, 0.75, lz0 + k + 0.8), BRASS, false)
	Build.box(_at, Vector3(1.0, 0.8, 2.2), Vector3(1.35, 0.4, (c.z0 + c.z1) * 0.5), WOOD)
	Build.box(_at, Vector3(1.1, 0.04, 2.3), Vector3(1.35, 0.82, (c.z0 + c.z1) * 0.5), Color("#E8DFC4"), false)
	Living.table_settings(self, 1.35, (c.z0 + c.z1) * 0.5, 0.84, 2.2, true)
	if comp_index("crew") < 0: # the S-boat's little galley, aft in the battery room
		Living.galley(self, c, -1.0, c.z0 + 5.0, c.z1 - 0.5)
	if comp_index("crew") < 0: # and no mess or rec room: her pastimes are at the wardroom table
		var wz: float = (c.z0 + c.z1) * 0.5
		Living.arm_table(self, 1.35, wz + 0.55, 0.84)
		Living.card_seats(self, [[0.67, wz - 0.55, -PI / 2.0]], 0.84, Vector3(1.35, 0, wz - 0.55))
	for z in [c.z0 + 2.0, c.z1 - 2.0]:
		Build.box(_at, Vector3(0.9, 0.03, 0.9), Vector3(0, 0.02, z), DARK, false)
		Build.box(_at, Vector3(0.3, 0.04, 0.05), Vector3(0, 0.05, z), BRASS, false)
	Build.label(_at, "BATTERY WELL", Vector3(0, 0.06, c.z0 + 2.0), 22, Color("#C9A04A")).rotation.x = -PI / 2.0
	_rack(c.type, c.z1 - 1.4)
	if comp_index("crew") < 0 and sub_class.gun_rounds > 0: # no crew's mess (S-boat): the magazine scuttle is aft in officers' country
		_add_station(AmmoStation.new().setup("ammo", "Ammunition scuttle"), Vector3(0, 0, c.z0 + 4.0)).set_meta("where", "wardroom")


func _control_room(c: Dictionary, hatch: Rect2) -> void:
	var z0: float = c.z0
	var z1: float = c.z1
	# Planes and ballast to port, helm to starboard; sonar and chart further aft.
	var cl := "conn" if not has_conning_tower else "helm_dive"
	_add_station(DiveStation.new().setup("dive", "Dive planes", "helm_dive"), Vector3(-1.85, 0, z0 + 2.0))
	# The fixed bilge pump, low on the forward bulkhead, port of the door, facing aft.
	_add_station(BilgeStation.new().setup("bilge", "Bilge pump"), Vector3(-1.05, 0, z0 + 0.3), PI / 2.0)
	_add_station(HelmStation.new().setup("helm", "Helm", cl), Vector3(1.8, 0, z0 + 2.0))
	_gauge_board(Vector3(-1.25, 1.7, z0 + 0.12), ["depth", "ordered"])
	_gauge_board(Vector3(1.25, 1.7, z0 + 0.12), ["speed", "heading", "battery"])
	_add_station(SonarStation.new().setup("sonar", "Sonar", "conn" if not has_conning_tower else ""), Vector3(-1.85, 0, z0 + 4.3))
	_add_station(BallastStation.new().setup("ballast", "Ballast manifold"), Vector3(-1.85, 0, z1 - 1.8))
	_add_station(NavStation.new().setup("nav", "Chart table"), Vector3(1.4, 0, z1 - 1.6))
	var mic := PaMic.new() # the PA, on the after bulkhead to port of the door
	mic.position = Vector3(-1.05, 0, z1 - 0.12)
	_at.add_child(mic)
	if not has_conning_tower:
		# S-boat: the periscope comes down into the control room and the TDC sits by the helm.
		_add_station(PeriscopeStation.new().setup("periscope", "Periscope", "conn"), Vector3(0, 0, z0 + 4.6))
		_add_station(TdcStation.new().setup("tdc", "Torpedo Data Computer", "conn"), Vector3(1.55, 0, z0 + 3.6))
		_rack(c.type, z0 + 5.4)
		if sub_class.gun_rounds == 0: # a missile boat carries no gun
			return
		# No conning tower: the ladder to the bridge hatch and the gun goes up from here.
		var gun := GunStation.new().setup("gun", "Deck gun") as GunStation
		gun.overhead = DECK_HEIGHT
		_add_station(gun, Vector3(0, 0, z0 + 6.6))
		return
	_rack(c.type, z0 + 4.4)
	# Ladder up to the conning tower.
	var ladder := Ladder.new()
	ladder.name = "ladder_ct"
	main_ladder = ladder
	_at.add_child(ladder)
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
		Build.box(_at, Vector3(0.2, h, z1 - z0), Vector3(side * hw, y, mid), WALL)
	Build.box(_at, Vector3(hw * 2.0, h, 0.2), Vector3(0, y, z0), WALL)
	Build.box(_at, Vector3(hw * 2.0, h, 0.2), Vector3(0, y, z1), WALL)
	Build.box(_at, Vector3(hw * 2.0, 0.2, z1 - z0), Vector3(0, CT_FLOOR + h + 0.1, mid), CEILING)
	var light := OmniLight3D.new()
	light.light_color = LIGHT
	light.light_energy = 1.1
	light.omni_range = 5.0
	light.position = Vector3(0, CT_FLOOR + h - 0.3, mid)
	_at.add_child(light)
	Build.sphere(_at, 0.08, Vector3(0, CT_FLOOR + h - 0.05, mid), LIGHT, 3.0)
	Build.label(_at, "CONNING TOWER", Vector3(0, CT_FLOOR + h - 0.25, z0 + 0.13), 40, Color("#2B2B26"))
	_add_station(PeriscopeStation.new().setup("periscope", "Attack periscope", "attack"), Vector3(0, CT_FLOOR, z1 - 0.9))
	_gauge_board(Vector3(0.3, CT_FLOOR + 1.7, z0 + 0.12), ["depth", "heading"])
	_add_station(TdcStation.new().setup("tdc", "Torpedo Data Computer", "attack"), Vector3(hw - 0.45, CT_FLOOR, z0 + 2.2))
	# The ladder up through the bridge hatch to the deck gun, port forward corner.
	var gun := GunStation.new().setup("gun", "Deck gun") as GunStation
	gun.overhead = h
	_add_station(gun, Vector3(-1.1, CT_FLOOR, z0 + 0.65))


func _crew(c: Dictionary) -> void:
	# Forward: rack (port); two mess tables to starboard, the urn on the after one; stores aft.
	_rack(c.type, c.z0 + 1.3, true)
	for tz: float in [c.z1 - 1.2, c.z0 + 2.2]:
		Build.box(_at, Vector3(0.9, 0.75, 1.8), Vector3(1.3, 0.38, tz), WOOD)
		Build.box(_at, Vector3(1.0, 0.04, 1.9), Vector3(1.3, 0.77, tz), Color("#E8DFC4"), false)
		Living.table_settings(self, 1.3, tz, 0.79, 1.8, tz < c.z1 - 2.0)
	Living.cribbage(self, Vector3(1.0, 0.79, c.z1 - 1.0))
	Living.arm_table(self, 1.3, c.z0 + 2.2, 0.79)
	# The galley along the port side (Gato: galley and mess share the after battery room).
	Living.galley(self, c, -1.0, c.z0 + 2.2, minf(c.z0 + 6.0, c.z1 - 2.0))
	# Photos and letters from home pinned up over the forward table.
	c["wall_gear"] = c.get("wall_gear", []) + [[1.0, c.z0 + 1.5, c.z0 + 2.9]]
	Build.box(_at, Vector3(0.02, 0.45, 0.8), Vector3(HALF_WIDTH - 0.02, 1.5, c.z0 + 2.2), Color("#A8845A"), false)
	for k in 4:
		Living.picture(self, Vector3(HALF_WIDTH - 0.04, 1.58 - (k / 2) * 0.17, c.z0 + 1.98 + (k % 2) * 0.42), -PI / 2.0, ["family", "letter", "pinup", "family"][k] if k != 2 else "letter", k + 1)
	# The cool room and the freezer are under the mess deck: their flush hatches.
	for h: Array in [[c.z0 + 1.0, "COOL ROOM" if sub_class.key != "typhoon" else "ХОЛОДИЛЬНИК"], [c.z0 + 6.6, "FREEZER" if sub_class.key != "typhoon" else "МОРОЗИЛКА"]]:
		if h[0] < c.z1 - 0.8:
			Build.box(_at, Vector3(0.7, 0.03, 0.7), Vector3(0.1, 0.02, h[0]), DARK, false)
			Build.box(_at, Vector3(0.25, 0.04, 0.04), Vector3(0.1, 0.05, h[0] + 0.2), BRASS, false)
			Build.label(_at, h[1], Vector3(0.1, 0.045, h[0] - 0.1), 16, BRASS).rotation.x = -PI / 2.0
	# The magazine is under the mess: its scuttle to port, opposite the table.
	if sub_class.gun_rounds > 0:
		_add_station(AmmoStation.new().setup("ammo", "Ammunition scuttle"), Vector3(0, 0, c.z1 - 3.4)).set_meta("where", "crew's mess")


## The crew's quarters (Blaney: "all the sleeping quarters should not be near the weapons or
## operation areas"): the boat's only bunks, three tiers either side of an aisle, amidships.
func _berthing(c: Dictionary, gap := {}) -> void:
	var z0: float = c.z0 + 0.7
	var z1: float = c.z1 - 0.7
	var bays := maxi(1, roundi((z1 - z0) / 2.1))
	var bay: float = (z1 - z0) / bays
	var blanket := Color("#3E5770")
	for side in [-1.0, 1.0]:
		for b in bays:
			var mid: float = z0 + bay * (b + 0.5)
			if side == gap.get("side", 0.0) and absf(mid - float(gap.z)) < bay * 0.5: # a door there
				continue
			for t in 3:
				var y: float = [0.32, 0.96, 1.6][t]
				var k := int(absf(mid) * 5.0) + b * 7 + t * 3 + (11 if side > 0.0 else 0)
				Build.box(_at, Vector3(0.75, 0.08, bay - 0.1), Vector3(side * 1.6, y, mid), WOOD)
				Build.box(_at, Vector3(0.7, 0.1, bay - 0.25), Vector3(side * 1.6, y + 0.09, mid), BUNK, false)
				Build.box(_at, Vector3(0.45, 0.09, 0.28), Vector3(side * 1.6, y + 0.18, mid - bay * 0.32), Color("#F2F0E8"), false)
				# Off-watch men asleep (Blaney: the sub should look lived in), two in each room.
				if (side < 0.0 and b == 0 and t == 0) or (side > 0.0 and b == bays - 1 and t == 1):
					Living.sleeper(self, Vector3(side * 1.6, y + 0.3, mid), bay, k)
					continue
				Build.box(_at, Vector3(0.68, 0.05, (bay - 0.25) * 0.6), Vector3(side * 1.6, y + 0.16, mid + bay * 0.15), blanket, false)
				Living.bunk_touches(self, Vector3(side * 1.6, y, mid), side, bay, k, t == 0, t == 2)
			# Stanchions between the bays.
			Build.cyl(_at, 0.025, 1.95, Vector3(side * 1.22, 0.97, mid - bay * 0.5), PIPE)
		Build.cyl(_at, 0.025, 1.95, Vector3(side * 1.22, 0.97, z1), PIPE)


## The navigation room (Blaney): mostly a giant hologram of everything in the water, the
## outside cameras' bank of screens on the port side forward, the captain's chair in the port
## after corner looking at the hologram (`chair`: the Typhoon's is in her command bay), a chart
## locker to starboard.
func _nav_room(c: Dictionary, chair := true) -> void:
	var mid: float = (c.z0 + c.z1) * 0.5
	var hz: float = mid + 0.6
	var holo := HoloView.new()
	holo.name = "nav_holo"
	holo.radius = minf(1.15, (c.z1 - c.z0) * 0.5 - 0.8)
	holo.height = 1.05
	holo.position = Vector3(0, 1.8, hz)
	_at.add_child(holo)
	# The projector: a ring in the deckhead over it, and a glow on the deck under it.
	Build.cyl(_at, holo.radius * 0.3, 0.06, Vector3(0, DECK_HEIGHT - 0.05, hz), Color("#2E3A44"), Vector3.UP)
	Build.sphere(_at, 0.08, Vector3(0, DECK_HEIGHT - 0.1, hz), Color("#4FC3FF"), 2.0)
	Build.cyl(_at, holo.radius * 0.35, 0.03, Vector3(0, 0.015, hz), Color("#2E3A44"), Vector3.UP, false)
	Build.sphere(_at, 0.05, Vector3(0, 0.05, hz), Color("#4FC3FF"), 2.0)
	# Stood out from the wall so its screens are in front of the pipe runs (Blaney: "there are
	# pipes in the way of the tv screen").
	_add_station(CameraStation.new().setup("cameras", "Outside cameras"), Vector3(-HALF_WIDTH + 1.32, 0, c.z0 + 1.8), PI / 2.0) # aft enough that the open door (1 m) hides no screen
	if chair:
		var at := Vector3(-1.05, 0, c.z1 - 0.75)
		var cap := CaptainStation.new().setup("captain", "Captain's chair") as CaptainStation
		var to := Vector3(0, 0, hz) - at
		cap.look = Vector3(0, 1.3, -to.length())
		_add_station(cap, at, atan2(-to.x, -to.z))
	# A chart locker of wide flat drawers in the starboard after corner, clear of the walkway.
	var lz: float = c.z1 - 0.75
	Build.box(_at, Vector3(0.55, 1.0, 1.0), Vector3(HALF_WIDTH - 0.4, 0.5, lz), WOOD)
	for k in 4:
		Build.box(_at, Vector3(0.02, 0.18, 0.85), Vector3(HALF_WIDTH - 0.68, 0.2 + k * 0.22, lz), Color("#5A3E26"), false)
		Build.box(_at, Vector3(0.03, 0.03, 0.16), Vector3(HALF_WIDTH - 0.7, 0.2 + k * 0.22, lz), Color("#C9A04A"), false)
	var title := Build.label(_at, "NAVIGATION", Vector3(HALF_WIDTH - 0.07, 2.0, mid), 40, Color("#2A2E2B"))
	title.rotation.y = -PI / 2.0
	if comp_index("rec") < 0:
		_band_rack(Vector3(HALF_WIDTH - 0.03, 1.3, c.z0 + 1.3), false)


## The rec room (lando: whimsical fun and mini games, apart from the patrol): a dartboard on
## the after bulkhead with a chalkboard of best turns, a jukebox, a card table, portholes.
func _rec_room(c: Dictionary) -> void:
	# The board on the starboard wall amidships (the bulkheads have doors); the oche across the room.
	var mid: float = (c.z0 + c.z1) * 0.5
	_add_station(DartsStation.new().setup("darts", "Darts"), Vector3(HALF_WIDTH - 0.06 - DartsStation.OCHE, 0, mid), -PI / 2.0)
	FunSpot.add(_at, "Darts", "[E] at the board: aim with the mouse, [LMB] or [Space] throws; best turns go up on the chalkboard", Vector3(HALF_WIDTH - 0.3, 2.2, mid))
	var jb := Jukebox.new()
	jb.position = Vector3(-1.45, 0, c.z0 + 0.6)
	jb.rotation.y = PI
	_at.add_child(jb)
	FunSpot.add(_at, "Jukebox", "[E] at the jukebox puts the next record on", jb.position + Vector3(0, 1.8, 0))
	for st in [Vector3(0.62, 0, c.z0 + 1.4), Vector3(1.3, 0, c.z0 + 2.1)]: # stools at the card table
		Build.cyl(_at, 0.18, 0.04, st + Vector3(0, 0.46, 0), Color("#3E5770"))
		Build.cyl(_at, 0.03, 0.44, st + Vector3(0, 0.22, 0), DARK)
	Living.card_seats(self, [[0.55, c.z0 + 1.4, -PI / 2.0], [1.3, c.z0 + 2.15, 0.0]], 0.76, Vector3(1.3, 0, c.z0 + 1.4))
	Build.box(_at, Vector3(0.9, 0.72, 0.9), Vector3(1.3, 0.36, c.z0 + 1.4), WOOD) # card table
	Build.box(_at, Vector3(1.0, 0.04, 1.0), Vector3(1.3, 0.74, c.z0 + 1.4), Color("#2B6A3A"), false) # baize
	Build.box(_at, Vector3(0.065, 0.03, 0.09), Vector3(1.6, 0.775, c.z0 + 1.1), Color("#F2F0E8"), false) # the deck
	var p := Porthole.create(Vector3(-HALF_WIDTH + 0.02, 1.6, (c.z0 + c.z1) * 0.5), -1.0)
	_at.add_child(p)
	portholes.append(p)
	_band_rack(Vector3(-HALF_WIDTH + 0.03, 1.35, c.z1 - 1.15), true)


## The ship's band's instruments (Blaney): in the rec room, or the navigation room on a boat without one.
func _band_rack(at: Vector3, port: bool) -> void:
	var rack := InstrumentRack.new()
	rack.position = at
	if port:
		rack.rotation.y = PI
	_at.add_child(rack)
	FunSpot.add(_at, "Ship's band", "[E] at the rack takes an instrument; hold [LMB] to play your part, [G] puts it back", at + Vector3(0, 0.9, 0))


func _engine_room(c: Dictionary, controls: bool) -> void:
	var z0: float = c.z0
	var z1: float = c.z1
	var eng_z0 := z0 + 2.5
	var eng_z1 := z1 - 2.6
	for side in [-1.0, 1.0]:
		var x: float = side * 1.3
		Build.box(_at, Vector3(1.1, 1.5, eng_z1 - eng_z0), Vector3(x, 0.75, (eng_z0 + eng_z1) * 0.5), Color("#4E5550"))
		var n := int((eng_z1 - eng_z0) / 1.08)
		for i in n:
			var rocker := Build.box(_at, Vector3(0.7, 0.25, 0.8), Vector3(x, 1.62, eng_z0 + 0.7 + i * 1.08), Color("#6E756C"), false)
			Build.cyl(_at, 0.05, 0.3, Vector3(x, 1.85, eng_z0 + 0.7 + i * 1.08), BRASS)
			rocker.set_meta("y", rocker.position.y)
			_rockers[0 if side < 0.0 else 1].append(rocker)
		Build.cyl(_at, 0.18, eng_z1 - eng_z0, Vector3(side * 1.55, 2.1, (eng_z0 + eng_z1) * 0.5), Color("#3A3A3A"), Vector3.BACK)
	_rack(c.type, z0 + 1.3, true)
	Living.picture(self, Vector3(1.45, 1.55, z0 + 0.12), 0.0, "pinup", int(z0))
	Living.picture(self, Vector3(1.15, 1.5, z0 + 0.12), 0.0, "letter", int(z0) + 1)
	if controls:
		_add_station(EngineStation.new().setup("engine", "Diesel controls"), Vector3(0, 0, z1 - 0.25), -PI / 2.0)


func _maneuvering(c: Dictionary) -> void:
	# The electrical control cubicle: rows of switch panels both sides.
	var cz0: float = c.z0 + 1.6
	var cz1: float = c.z1 - 0.4
	for side in [-1.0, 1.0]:
		Build.box(_at, Vector3(0.4, 1.8, cz1 - cz0), Vector3(side * 1.75, 0.9, (cz0 + cz1) * 0.5), DARK)
		for i in 4:
			Build.box(_at, Vector3(0.04, 0.12, 0.06), Vector3(side * 1.53, 1.0 + (i % 2) * 0.4, cz0 + 0.4 + i * 0.8), BRASS, false)
	_rack(c.type, c.z0 + 0.8)


## The air panel and the spare-parts stores live in the first compartment aft of the control
## room on every boat (crew's mess, or the S-boat's engine room).
func _air_and_stores() -> void:
	var k := comp_index("control") + 1
	var c: Dictionary = compartments[mini(k, compartments.size() - 1)]
	_add_station(AirStation.new().setup("air", "Air panel"), Vector3(1.8, 0, c.z0 + 1.3))
	var crate := PartsCrate.new()
	crate.position = Vector3(-1.35, 0, c.z1 - 1.1)
	_at.add_child(crate)


## Detail every compartment shares, so the hull reads as a working boat (lando: art toward
## Sea of Thieves, a bit more detailed): ring frames over the deckhead and down the shoulders,
## a cable run with brass clamps, red handwheels on the pipe runs, a wire cage round each
## bulb, an extinguisher by the after door, stencilled frame numbers. None of it collides.
func _dressing(c: Dictionary, hatch: Rect2) -> void:
	var z0: float = c.z0
	var z1: float = c.z1
	var frame_col := Color("#8FA88C")
	var n := int((z1 - z0) / 1.2)
	for i in range(1, n):
		var z := z0 + (z1 - z0) * i / n
		if hatch.size != Vector2.ZERO and z > hatch.position.y - 0.15 and z < hatch.end.y + 0.15:
			continue
		Build.box(_at, Vector3(2.5, 0.07, 0.1), Vector3(0, DECK_HEIGHT - 0.03, z), frame_col, false)
		for side in [-1.0, 1.0]:
			if _near_porthole(side, z):
				continue
			Build.arc(_at, Vector2(side * (HALF_WIDTH - SHOULDER_R), DECK_HEIGHT - SHOULDER_R), SHOULDER_R - 0.07,
					0.0 if side > 0.0 else PI * 0.5, PI * 0.5 if side > 0.0 else PI, 0.07, z - 0.05, z + 0.05, frame_col)
			Build.box(_at, Vector3(0.07, DECK_HEIGHT - SHOULDER_R - 0.4, 0.1), Vector3(side * (HALF_WIDTH - 0.035), (DECK_HEIGHT - SHOULDER_R + 0.4) * 0.5, z), frame_col, false)
			# Cable clamps on the frame.
			Build.box(_at, Vector3(0.16, 0.05, 0.05), Vector3(side * 0.62, DECK_HEIGHT - 0.1, z), BRASS, false)
		if i % 2 == 0:
			Build.label(_at, "FR %d" % (int(z * 2.0) + 60), Vector3(0.0, DECK_HEIGHT - 0.12, z + 0.051), 18, Color("#2B2B26"))
	# Cable runs under the deckhead, both sides of the light line.
	var cables := [Color("#2B2B26"), Color("#7A2E25"), Color("#3E5770")]
	for side in [-1.0, 1.0]:
		for k in cables.size():
			Build.cyl(_at, 0.022, z1 - z0 - 0.3, Vector3(side * (0.56 + k * 0.05), DECK_HEIGHT - 0.06, (z0 + z1) * 0.5), cables[k], Vector3.BACK)
	# Handwheel valves on the white pipe runs.
	var m := maxi(1, int((z1 - z0) / 3.5))
	for i in m:
		var z := z0 + (z1 - z0) * (i + 0.5) / m
		var side := -1.0 if i % 2 == 0 else 1.0
		Build.cyl(_at, 0.1, 0.18, Vector3(side * 1.1, DECK_HEIGHT - 0.1, z), Color("#8A8F86"), Vector3.BACK)
		Build.cyl(_at, 0.015, 0.14, Vector3(side * 1.1, DECK_HEIGHT - 0.22, z), Color("#8A8F86"))
		Build.wheel(_at, 0.09, Vector3(side * 1.1, DECK_HEIGHT - 0.29, z), RED, Vector3.DOWN)
	# Wire cages round the bulbs.
	var bulbs := maxi(1, roundi((z1 - z0) / 5.0))
	for i in bulbs:
		var z := z0 + (z1 - z0) * (i + 0.5) / bulbs
		for k in 2:
			var w := Build.box(_at, Vector3(0.22, 0.015, 0.015), Vector3(0, DECK_HEIGHT - 0.1, z), DARK, false)
			w.rotation.y = k * PI / 2.0
		Build.wheel(_at, 0.11, Vector3(0, DECK_HEIGHT - 0.07, z), DARK, Vector3.DOWN)
	# The ventilation trunk along the deckhead, port of the lamps, a grille every couple of metres
	# (Blaney: more pipes and stuff, the boat full and working, the walkway kept clear).
	var dz0 := z0 + 0.3
	var dz1 := z1 - 0.3
	Build.box(_at, Vector3(0.26, 0.18, dz1 - dz0), Vector3(-0.82, DECK_HEIGHT - 0.12, (dz0 + dz1) * 0.5), Color("#8A9486"), false)
	var g := dz0 + 1.0
	while g < dz1 - 0.5:
		Build.box(_at, Vector3(0.2, 0.02, 0.3), Vector3(-0.82, DECK_HEIGHT - 0.215, g), DARK, false)
		g += 2.2
	# An extinguisher on the after bulkhead by the door, port side.
	if c != compartments[-1]:
		var ez := z1 - 0.2
		Build.cyl(_at, 0.09, 0.5, Vector3(-1.3, 0.55, ez), RED)
		Build.sphere(_at, 0.09, Vector3(-1.3, 0.8, ez), RED)
		Build.cyl(_at, 0.03, 0.08, Vector3(-1.3, 0.92, ez), DARK)
		Build.box(_at, Vector3(0.14, 0.03, 0.03), Vector3(-1.25, 0.95, ez), DARK, false)
		Build.box(_at, Vector3(0.24, 0.04, 0.08), Vector3(-1.3, 0.62, ez + 0.06), DARK, false) # strap
	match c.type:
		"crew":
			# Coffee urn and mugs on the mess table, a menu board.
			var tz: float = z1 - 1.2
			Build.cyl(_at, 0.13, 0.4, Vector3(1.5, 0.99, tz - 0.6), Color("#8A8F86"))
			Build.cyl(_at, 0.14, 0.03, Vector3(1.5, 1.2, tz - 0.6), DARK)
			Build.particles(_at, Color(1, 1, 1, 0.22), 6, 2.0, Vector3.UP, 0.15, 15.0, Vector3(0, 0.03, 0), 0.07).position = Vector3(1.5, 1.24, tz - 0.6)
			Build.box(_at, Vector3(0.06, 0.03, 0.03), Vector3(1.4, 0.9, tz - 0.6), DARK, false)
			for k in 4:
				Build.cyl(_at, 0.04, 0.09, Vector3(1.1 + (k % 2) * 0.35, 0.83, tz - 0.2 + (k / 2) * 0.55), Color("#E8DFC4"))
			Build.box(_at, Vector3(0.03, 0.5, 0.7), Vector3(HALF_WIDTH - 0.02, 1.55, tz - 1.4), Color("#2F3A30"), false).rotation.y = 0.0
			var menu := Build.label(_at, "СЕГОДНЯ\nБОРЩ И КАША\nЧАЙ" if sub_class.key == "typhoon" else "TODAY\nSPAM & BEANS\nCOFFEE", Vector3(HALF_WIDTH - 0.04, 1.55, tz - 1.4), 20, Color("#F2F0E8"))
			menu.rotation.y = -PI / 2.0
		"battery":
			# Officers' books on a shelf over the wardroom table, a brass clock.
			var bz: float = (z0 + z1) * 0.5
			Build.box(_at, Vector3(0.22, 0.03, 1.2), Vector3(1.85, 1.25, bz + 0.3), WOOD, false)
			var cols := [Color("#7A2E25"), Color("#3E5770"), Color("#2F4A2E"), Color("#6B5A44"), Color("#7A2E25"), Color("#2B2B26")]
			for k in cols.size():
				Build.box(_at, Vector3(0.16, 0.22 - (k % 3) * 0.03, 0.06), Vector3(1.86, 1.38 - (k % 3) * 0.015, bz - 0.2 + k * 0.09), cols[k], false)
			for k in 2: # the officers' photos of home, standing on the shelf
				Living.picture(self, Vector3(1.86, 1.33, bz + 0.5 + k * 0.2), -PI / 2.0, "family", k + 2)
			Build.cyl(_at, 0.07, 0.2, Vector3(1.35, 0.94, bz - 0.15), Color("#8A8F86")) # the coffee pot
		"control":
			# The boat's clock over the depth board.
			Build.cyl(_at, 0.15, 0.05, Vector3(-1.15, 2.2, z0 + 0.13), BRASS, Vector3.BACK)
			Build.cyl(_at, 0.12, 0.02, Vector3(-1.15, 2.2, z0 + 0.16), Color("#F2E8CF"), Vector3.BACK)
			var hand := Build.box(_at, Vector3(0.015, 0.09, 0.01), Vector3(-1.13, 2.24, z0 + 0.18), DARK, false)
			hand.rotation.z = -0.5


## The Typhoon's paint as in The Hunt for Red October: cold blue-grey steel, not WWII green.
const TYPHOON_PAINT := {"9db59aff": Color("#8E9BA6"), "b5c4b0ff": Color("#A9B3BB"), "8fa88cff": Color("#7D8A95"), "5e6b5cff": Color("#4E555C")}
## Rooms whose walls are taken up by their own gear: only the pipe runs there.
const BUSY_WALLS := ["fwd_torpedo", "aft_torpedo", "berthing", "berthing2", "missile", "reactor", "reactor2", "engine", "engine2", "rec", "sonar", "radio", "sauna", "sickbay"]


## Packed like the real boats (Blaney: Gato like WWII photos; the Typhoon like the film): pipe runs
## in four colours high on both walls and one along the bilge, and between the stations on the
## walls handwheel valves, gauges, junction boxes with stencils, pipe drops and cable looms.
## `gaps`: z of doors in the side walls, kept clear.
func _clutter(c: Dictionary, gaps: Array) -> void:
	var z0: float = c.z0
	var z1: float = c.z1
	var mid := (z0 + z1) * 0.5
	var red := sub_class.key == "typhoon"
	var runs: Array = [Color("#8A8F86"), Color("#3E5770"), Color("#C9A04A"), RED] if red else [PIPE, Color("#6E7F6A"), RED, Color("#3E5770")]
	var stencil := ["ВОДА", "ВОЗДУХ ВД", "ГИДРАВЛИКА", "ПОЖАРНЫЙ"] if red else ["FRESH WATER", "HP AIR", "HYDRAULIC", "FIRE MAIN"]
	for side in [-1.0, 1.0]:
		for k in runs.size():
			var y := 1.92 + k * 0.09
			var x: float = side * (HALF_WIDTH - 0.1 - k * 0.04 - (y - 1.85) * 0.35)
			Build.cyl(_at, 0.028 if k % 2 == 0 else 0.022, z1 - z0 - 0.3, Vector3(x, y, mid), runs[k], Vector3.BACK)
		Build.cyl(_at, 0.035, z1 - z0 - 0.3, Vector3(side * 1.78, 0.28, mid), Color("#5A5E56"), Vector3.BACK)
		if true: # every boat (Blaney: fill her up, more pipes; then the other boats as well): a second bank up on the shoulder, a bilge pair
			for k in 4:
				var y2 := 2.22 + k * 0.08
				var r2 := SHOULDER_R - 0.06
				var x2: float = side * (HALF_WIDTH - SHOULDER_R + sqrt(maxf(r2 * r2 - pow(y2 - (DECK_HEIGHT - SHOULDER_R), 2.0), 0.0)))
				var bank: Array = [Color("#6E7F6A"), Color("#C9A04A"), Color("#8A8F86"), Color("#3E5770")] if red else [Color("#8A8F86"), BRASS, Color("#5A6048"), PIPE]
				Build.cyl(_at, 0.035 if k % 2 == 0 else 0.026, z1 - z0 - 0.3, Vector3(x2, y2, mid), bank[k], Vector3.BACK)
			Build.cyl(_at, 0.05, z1 - z0 - 0.3, Vector3(side * 1.62, 0.42, mid), Color("#3E5770"), Vector3.BACK)
	if true: # a bundle along the deckhead each side of the lamps, clamped at every frame
		for k in 3:
			for side in [-1.0, 1.0]:
				Build.cyl(_at, 0.04 - k * 0.008, z1 - z0 - 0.3, Vector3(side * (0.28 + k * 0.1), DECK_HEIGHT - 0.04, mid), [Color("#8A8F86"), RED, Color("#E8E0C8")][k] if red else [PIPE, Color("#2B2B26"), Color("#7A2E25")][k], Vector3.BACK)
		var f := z0 + 0.8
		while f < z1 - 0.5:
			Build.box(_at, Vector3(0.9, 0.04, 0.05), Vector3(0, DECK_HEIGHT - 0.04, f), DARK, false)
			f += 1.6
	if c.type in BUSY_WALLS and not (red and c.type in ["missile", "engine", "engine2", "sonar", "radio"]):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(z0 * 13.0) + 7
	var taken: Array = [] # [side, z] of the stations and racks on the walls
	for st: Station in stations.values():
		if st.get_parent() == _at and absf(st.position.x) > 1.0:
			taken.append([signf(st.position.x), st.position.z])
	for z: float in c.get("keep_clear", []): # big gear against both walls (a sauna, consoles)
		taken.append([-1.0, z])
		taken.append([1.0, z])
	for side in [-1.0, 1.0]:
		var z := z0 + 0.9
		var n := 0
		while z < z1 - 0.9:
			var clear := not _near_porthole(side, z) and not gaps.any(func(g: float) -> bool: return absf(g - z) < 1.0) \
				and not taken.any(func(t: Array) -> bool: return t[0] == side and absf(t[1] - z) < 1.1) and not _gear_against(c, side, z)
			if clear:
				var x: float = side * (HALF_WIDTH - 0.06)
				match n % 5:
					0: # a handwheel valve on a stub off the pipe run
						Build.cyl(_at, 0.02, 0.45, Vector3(x, 1.68, z), runs[n % runs.size()])
						Build.cyl(_at, 0.045, 0.1, Vector3(x - side * 0.05, 1.5, z), Color("#8A8F86"), Vector3.RIGHT)
						Build.wheel(_at, 0.1, Vector3(x - side * 0.12, 1.5, z), RED if rng.randf() < 0.6 else Color("#3E5770"), Vector3.LEFT if side > 0.0 else Vector3.RIGHT)
					1: # a pair of gauges
						for dz in [-0.13, 0.13]:
							Build.cyl(_at, 0.075, 0.04, Vector3(x - side * 0.02, 1.55, z + dz), BRASS, Vector3.RIGHT)
							Build.cyl(_at, 0.064, 0.02, Vector3(x - side * 0.045, 1.55, z + dz), Color("#F2E8CF"), Vector3.RIGHT)
							var needle := Build.box(_at, Vector3(0.01, 0.05, 0.008), Vector3(x - side * 0.06, 1.56, z + dz), DARK, false)
							needle.rotation.x = rng.randf_range(-1.2, 1.2)
							needle.set_meta("a", needle.rotation.x)
							_needles.append(needle)
					2: # a junction box with its stencil
						Build.box(_at, Vector3(0.12, 0.34, 0.28), Vector3(x - side * 0.03, 1.45, z), Color("#5A6048") if not red else Color("#6B747C"), false)
						var lab := Build.label(_at, stencil[rng.randi() % stencil.size()], Vector3(x - side * 0.095, 1.67, z), 14, Color("#E8E0C8"))
						lab.rotation.y = -PI / 2.0 if side > 0.0 else PI / 2.0
					3: # a pipe dropping from the run to the deck, with a flange
						Build.cyl(_at, 0.03, 1.85, Vector3(x, 0.93, z), runs[(n + 1) % runs.size()])
						Build.cyl(_at, 0.05, 0.04, Vector3(x, 1.1, z), Color("#8A8F86"))
					4: # a cable loom down the wall to a switch box
						for k in 3:
							Build.cyl(_at, 0.012, 0.8, Vector3(x - side * 0.01, 1.6, z - 0.04 + k * 0.04), [Color("#2B2B26"), Color("#7A2E25"), Color("#3E5770")][k])
						Build.box(_at, Vector3(0.1, 0.2, 0.18), Vector3(x - side * 0.02, 1.15, z), DARK, false)
						Build.sphere(_at, 0.018, Vector3(x - side * 0.075, 1.2, z), UiKit.GOOD if rng.randf() < 0.5 else Color("#E8B04A"), 2.0)
				n += 1
			z += rng.randf_range(0.55, 0.85)


## The WWII control room's real gear: the "Christmas tree" (the hull-opening board, a green or
## red lamp for every hatch, vent and valve: all green, she can dive), the high-pressure air
## manifold's row of valve wheels, and the 1MC phone handsets on their hooks.
func _wwii_control_gear(c: Dictionary) -> void:
	_at = self
	var z0: float = c.z0
	var z1: float = c.z1
	var board := Node3D.new()
	board.position = Vector3(1.2, 1.05, z0 + 0.13)
	add_child(board)
	Build.box(board, Vector3(0.8, 0.55, 0.05), Vector3.ZERO, Color("#1E1E1E"), false)
	Build.label(board, "HULL OPENINGS", Vector3(0, 0.22, 0.03), 14, Color("#E8E0C8"))
	_tree_lamps.clear()
	for row in 4:
		for col in 8:
			var lamp := Build.sphere(board, 0.018, Vector3(-0.32 + col * 0.09, 0.12 - row * 0.1, 0.03), UiKit.GOOD, 2.0)
			_tree_lamps.append(lamp)
	var man := Node3D.new() # HP air manifold on the after bulkhead, starboard of the door
	man.position = Vector3(1.15, 1.55, z1 - 0.14)
	add_child(man)
	Build.cyl(man, 0.04, 0.9, Vector3.ZERO, BRASS, Vector3.RIGHT)
	for k in 6:
		Build.cyl(man, 0.015, 0.12, Vector3(-0.38 + k * 0.15, 0, -0.06), Color("#8A8F86"), Vector3.BACK)
		Build.wheel(man, 0.055, Vector3(-0.38 + k * 0.15, 0, -0.13), RED if k < 3 else Color("#3E5770"), Vector3.FORWARD)
	Build.label(man, "H.P. AIR", Vector3(0, 0.14, -0.02), 14, Color("#2B2B26")).rotation.y = PI
	# Pipe risers up all four corners, and valve manifolds overhead either side of the walkway,
	# their handwheels hanging on reach rods (Blaney: more pipes, but easy to move around).
	for corner: Vector2 in [Vector2(-1, z0 + 0.25), Vector2(1, z0 + 0.25), Vector2(-1, z1 - 0.25), Vector2(1, z1 - 0.25)]:
		for k in 3:
			Build.cyl(self, 0.03 - k * 0.005, 1.95, Vector3(corner.x * (1.86 - k * 0.07), 0.975, corner.y), [PIPE, RED, Color("#3E5770")][k])
	for side in [-1.0, 1.0]:
		var mx: float = side * 1.28
		var a := z0 + 2.9
		var b := z1 - 2.4
		Build.cyl(self, 0.045, b - a, Vector3(mx, DECK_HEIGHT - 0.24, (a + b) * 0.5), Color("#6E7F6A") if side < 0.0 else BRASS, Vector3.BACK)
		var n := int((b - a) / 0.5)
		for k in n + 1:
			var vz := a + (b - a) * k / maxf(1.0, n)
			Build.cyl(self, 0.012, 0.18, Vector3(mx, DECK_HEIGHT - 0.36, vz), Color("#8A8F86"))
			Build.wheel(self, 0.065, Vector3(mx, DECK_HEIGHT - 0.46, vz), RED if k % 2 == 0 else Color("#3E5770"), Vector3.DOWN)
		Build.label(self, "HYDRAULIC" if side < 0.0 else "LOW PRESSURE BLOW", Vector3(mx, DECK_HEIGHT - 0.3, a - 0.15), 12, Color("#2B2B26"))
	for k in 2: # phone handsets on the port wall
		var z := z0 + 3.2 + k * 0.25
		Build.box(self, Vector3(0.06, 0.2, 0.12), Vector3(-1.93, 1.55, z), Color("#2B2B26"), false)
		Build.box(self, Vector3(0.05, 0.06, 0.06), Vector3(-1.89, 1.68, z), Color("#1E1E1E"), false)


var _tree_lamps: Array[MeshInstance3D] = []
var _stirring: Array[Node3D] = [] ## the cooks' stirring arms
var _needles: Array[Node3D] = [] ## gauge needles, trembling as she runs
var _tree_red := -1


## The board: the main induction and hull ventilation lamps go red while the diesels breathe
## on the surface; dived, a straight board, all green.
func _tree(sub: SubState) -> void:
	var red := 2 if sub.is_surfaced() and sub.diesels_running() > 0 else 0
	if red == _tree_red or _tree_lamps.is_empty():
		return
	_tree_red = red
	for k in _tree_lamps.size():
		_tree_lamps[k].material_override = Build.mat(RED if k < red else UiKit.GOOD, 2.0)


## A Typhoon room's own big gear standing against that wall there (TyphoonLayout._fit).
func _gear_against(c: Dictionary, side: float, z: float) -> bool:
	for g: Array in c.get("wall_gear", []): # a galley, a notice board: [side, z from, z to]
		if g[0] == side and z > g[1] and z < g[2]:
			return true
	match c.type:
		"radio":
			return side > 0.0 and z < c.z0 + 9.2
		"sonar":
			return z < c.z0 + 5.8
		"engine", "engine2":
			return side > 0.0 and z > c.z0 + 2.5 and z < c.z1 - 10.5
		"missile":
			for k in 10:
				if absf(z - lerpf(c.z0 + 6.0, c.z1 - 6.0, k / 9.0)) < 0.9:
					return true
	return false


func _near_porthole(side: float, z: float) -> bool:
	for p in portholes:
		if signf(p.position.x) == side and absf(p.position.z - z) < Porthole.RADIUS + 0.25:
			return true
	return false


func _gauge_board(pos: Vector3, kinds: Array) -> void:
	var board := Node3D.new()
	board.position = pos
	_at.add_child(board)
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
		var s: Station = stations[sid]
		var root: Node3D = s.get_parent() if s.get_parent() is Node3D else self
		if _rooms.has(root):
			out[sid] = _rooms.find(root) # a Typhoon's rooms overlap in z
			continue
		var z: float = s.position.z
		for i in compartments.size():
			if z >= compartments[i].z0 and z < compartments[i].z1:
				out[sid] = i
	return out


## A close blast shakes paint flakes and dust down from the deckhead all through the boat.
func shake_loose(strength: float) -> void:
	for c in compartments:
		var p := Build.particles(self, Color(0.45, 0.5, 0.42, 0.8), int(10 + 30 * strength), 1.6, Vector3.DOWN, 0.5, 40.0, Vector3(0, -6, 0), 0.018)
		p.position = Vector3(c.get("x", 0.0), c.get("y", 0.0) + DECK_HEIGHT - 0.1, (c.z0 + c.z1) * 0.5)
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
	var typhoon := sub_class.key == "typhoon"
	var battle := false # all hands only fills the boat; it doesn't change her mood (Blaney)
	var base := TYPHOON_LIGHT if typhoon else LIGHT
	for l in _lights:
		var on := _flicker == 0.0 or randf() > _flicker * 0.7
		l.light_energy = l.get_meta("energy") * power * (1.0 if on else 0.08) * (0.8 if red or battle else 1.0)
		l.light_color = BATTLE_RED if battle else (Color("#FF4A35") if red else base)
	if typhoon and _env != null:
		_env.ambient_light_color = Color("#5A2E2A") if battle or red else Color("#5E6E80")
	for i in _rockers.size():
		var shake := 0.012 if sub.diesels[i] >= 1.0 else (0.006 if sub.diesels[i] > 0.0 else 0.0)
		for r: MeshInstance3D in _rockers[i]:
			r.position.y = r.get_meta("y") + randf_range(-shake, shake)
	_sounds(sub, delta)
	_tree(sub)
	var t := Time.get_ticks_msec() / 1000.0
	for a: Node3D in _stirring:
		a.rotation.x = 0.9 + sin(t * 3.0) * 0.2
		a.rotation.z = cos(t * 3.0) * 0.15
	var hum := 0.03 if sub.diesels_running() > 0 else 0.008
	for k in _needles.size():
		_needles[k].rotation.x = float(_needles[k].get_meta("a")) + sin(t * (5.0 + k % 7)) * hum
	_sync_teams(delta)
	_cull_rooms(delta)
	_muffle(delta)
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
		_typhoon_sounds(sub, delta)
		return
	var running := sub.diesels_running()
	_diesel_sound.volume_db = -80.0 if running == 0 else (-4.0 if running == 2 else -9.0)
	var on_motors := running == 0 and absf(sub.speed) > 0.1
	var flank := clampf(absf(sub.speed) / (sub.data.submerged_speed_kn * SubState.KNOT), 0.0, 1.0)
	_motor_sound.volume_db = linear_to_db(lerpf(0.12, 1.0, flank * flank)) - 10.0 if on_motors else -80.0
	_motor_sound.pitch_scale = 0.85 + 0.3 * flank
	# Rain drumming on the casing and the bridge, heard through the boat near the surface.
	var shallow := clampf((sub.data.periscope_depth + 4.0 - sub.depth) / (sub.data.periscope_depth + 4.0 - SubState.AWASH_DEPTH), 0.0, 1.0)
	var rain := Sim.world.conditions.rain_at(sub.pos) * shallow
	_rain_sound.volume_db = linear_to_db(maxf(rain, 0.0001)) - 2.0
	_rain_sound.stream_paused = rain <= 0.01
	if sub.vents_open and not _vents_were:
		Sfx.play("klaxon")
	_vents_were = sub.vents_open
	_deep(sub, delta, 0.8)


## Deep down it gets scary (Blaney): the hull creaks more and louder the deeper she goes; near
## her test depth the frames bang like gunshots, the boat jolts and water weeps from the seams;
## past it the lights waver. `pitch` is the boat's voice (a Typhoon's is lower).
func _deep(sub: SubState, delta: float, pitch: float) -> void:
	var deep := sub.depth / float(sub.data.test_depth)
	_creak_timer -= delta
	if _creak_timer <= 0.0:
		_creak_timer = randf_range(6.0, 14.0) / maxf(0.25, deep * deep * 2.0)
		if deep > 0.3:
			var c: Dictionary = compartments[randi() % compartments.size()]
			var at := Vector3(c.get("x", 0.0) + randf_range(-1.8, 1.8), c.get("y", 0.0) + 2.0, randf_range(c.z0, c.z1))
			Sfx.play_at(self, "creak_%d" % randi_range(1, 3), at, lerpf(-14.0, 2.0, clampf(deep - 0.3, 0.0, 1.0)), randf_range(pitch, pitch + 0.3))
			if deep > 0.85 and randf() < clampf((deep - 0.85) * 3.0, 0.15, 0.8): # a frame takes the strain: bang
				Sfx.play_at(self, "creak_%d" % randi_range(1, 3), at, 6.0, pitch * 0.55)
				var me := Game.instance.local_player
				if me != null:
					me.trauma = maxf(me.trauma, 0.25 + 0.2 * clampf(deep - 1.0, 0.0, 1.0))
				_weep(at)
				if deep > 1.0:
					flicker(0.3)


## A thin spray of water weeping from a seam in the deckhead.
func _weep(at: Vector3) -> void:
	var p := Build.particles(self, Color(0.7, 0.8, 0.85, 0.7), 24, 1.4, Vector3.DOWN, 0.8, 15.0, Vector3(0, -9.8, 0), 0.012)
	p.position = at + Vector3(0, DECK_HEIGHT - 2.1, 0)
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)


## A Typhoon's noises: the turbines' soft whirr aft, a klaxon pitched down, deep slow creaks.
func _typhoon_sounds(sub: SubState, delta: float) -> void:
	if _motor_sound == null:
		return
	var flank := clampf(absf(sub.speed) / (sub.data.submerged_speed_kn * SubState.KNOT), 0.0, 1.0)
	_motor_sound.volume_db = linear_to_db(lerpf(0.12, 1.0, flank * flank)) - 10.0
	_motor_sound.pitch_scale = 0.7 + 0.25 * flank
	if sub.vents_open and not _vents_were:
		Sfx.play("klaxon", 0.0, 0.8)
	_vents_were = sub.vents_open
	_deep(sub, delta, 0.6)


## Keeps a Typhoon's frame rate up (Blaney: "make sure this sub change doesn't lag anything out"):
## only the room you're in and what you could see through open doors is drawn.
func _cull_rooms(delta: float) -> void:
	if _rooms.is_empty():
		return
	_cull_timer -= delta
	if _cull_timer > 0.0:
		return
	_cull_timer = 0.15
	var me: Player = Game.instance.local_player if Game.instance != null else null
	if me == null:
		return
	var seen := {}
	if not Deck.is_out(me.global_position):
		var here := Sim.world.hull.comp_at_pos(me.camera.global_position)
		seen[here] = true
		var doors_now: Dictionary = Game.instance.crew.get("doors", {})
		var edge: Array[int] = [here]
		for hop in VIEW_HOPS:
			var next: Array[int] = []
			for link: Array in _room_links:
				if link[0] != "" and not doors_now.get(link[0], true):
					continue
				for k in 2:
					var a: int = link[1 + k]
					var b: int = link[2 - k]
					if edge.has(a) and not seen.has(b):
						seen[b] = true
						next.append(b)
			edge = next
	for i in _rooms.size():
		var show := seen.has(i)
		if _rooms[i].visible != show:
			_rooms[i].visible = show
			if show:
				people_room(i)


## Shut watertight doors keep the noise in (Blaney): a sound from a room behind one comes through
## dull (Sfx.MUFFLED's low-pass) and capped quieter, and quieter again for each more door.
func _muffle(delta: float) -> void:
	_muffle_timer -= delta
	if _muffle_timer > 0.0:
		return
	_muffle_timer = 0.2
	var me: Player = Game.instance.local_player if Game.instance != null else null
	var shut := {} # room -> closed doors between it and us
	if me != null and not Deck.is_out(me.global_position):
		var doors_now: Dictionary = Game.instance.crew.get("doors", {})
		shut[Sim.world.hull.comp_at_pos(me.camera.global_position)] = 0
		var edge: Array = shut.keys()
		while not edge.is_empty(): # closed doors cost one, open ones and hatches nothing
			var next: Array = []
			for link: Array in _walk_links():
				var cost := 0 if link[0] == "" or doors_now.get(link[0], true) else 1
				for k in 2:
					var a: int = link[1 + k]
					var b: int = link[2 - k]
					if edge.has(a) and int(shut.get(b, 99)) > int(shut[a]) + cost:
						shut[b] = int(shut[a]) + cost
						next.append(b)
			edge = next
	for n: Node in get_tree().get_nodes_in_group(Sfx.GROUP):
		var p := n as AudioStreamPlayer3D
		var doors_between := 0
		if not shut.is_empty() and not Deck.is_out(p.global_position):
			doors_between = int(shut.get(Sim.world.hull.comp_at_pos(p.global_position), 0))
		p.bus = Sfx.MUFFLED if doors_between > 0 else &"Effects"
		p.max_db = 3.0 if doors_between == 0 else -12.0 - 8.0 * (doors_between - 1)


## Apply host crew state: doors.
func apply_crew(crew: Dictionary) -> void:
	for id: String in crew.doors:
		if doors.has(id):
			doors[id].set_open(crew.doors[id])
	_sync_bots(crew.get("bots", {}))
	_sync_crowd(crew)
	TyphoonLayout.sync_band(self, crew)


const SAILORS_PER_ROOM := 3
var _crowd: Array[Node3D] = []
var _crowded := false
var _peopled := {} ## compartment index -> true once its sailors stand there


## "All hands" (crew.full_crew): sailors standing about every room, see-through so they never
## block the way (Blaney). On a Typhoon only rooms in sight get theirs (people_room as each is shown):
## 160 men wouldn't run.
func _sync_crowd(crew: Dictionary) -> void:
	var want: bool = crew.get("full_crew", false)
	if want == _crowded:
		return
	_crowded = want
	if not want:
		for v in _crowd:
			v.queue_free()
		_crowd.clear()
		_peopled.clear()
		return
	for k in compartments.size():
		if _rooms.is_empty() or _rooms[k].visible:
			people_room(k)


## Sailors for one compartment, the first time it's seen with the full crew aboard: in the
## aisle, clear of the stations, turned every which way.
func people_room(k: int) -> void:
	if not _crowded:
		return
	var root: Node3D = _rooms[k] if not _rooms.is_empty() else self
	if _peopled.has(k):
		return
	_peopled[k] = true
	var c: Dictionary = compartments[k]
	var rng := RandomNumberGenerator.new()
	rng.seed = k * 97 + 3
	var origin := Vector3(float(c.get("x", 0.0)), float(c.get("y", 0.0)), 0.0) if root == self else Vector3.ZERO
	var x_max := 0.0 if String(c.type).begins_with("engine") and sub_class.key == "typhoon" else 0.5 # clear of the turbine
	var z0: float = c.z0 + 1.5
	var z1: float = c.z0 + 4.0 if c.type == "steering" else c.z1 - 1.5 # clear of the rudder ram
	var placed := 0
	for n in SAILORS_PER_ROOM * 6:
		if placed >= SAILORS_PER_ROOM:
			break
		var p := origin + Vector3(rng.randf_range(-0.5, x_max), 0.0, rng.randf_range(z0, z1))
		var gp := root.global_transform * (p - origin) if root != self else p
		if stations.values().any(func(st: Station) -> bool: return Vector2(st.global_position.x - gp.x, st.global_position.z - gp.z).length() < 1.1):
			continue
		var look := {"build": rng.randi() % 4, "skin": rng.randi() % 3, "hair": rng.randi() % 7, "hair_col": rng.randi() % 7,
			"beard": rng.randi() % 3, "hat": "watch", "hue": 0.62}
		var v := _sailor(look)
		remove_child(v)
		root.add_child(v)
		v.position = p
		v.rotation.y = rng.randf() * TAU
		_crowd.append(v)
		placed += 1


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


var _team_views: Array[Node3D] = []


## The damage party's men, walking to their jobs (BotCrew), from the hull snapshot.
func _sync_teams(delta: float) -> void:
	var teams := Sim.world.hull.teams
	while _team_views.size() < teams.size():
		_team_views.append(_sailor({"hat": "watch", "build": _team_views.size() % 4, "skin": _team_views.size() % 6, "hue": 0.58}))
	while _team_views.size() > teams.size():
		_team_views.pop_back().queue_free()
	for i in teams.size():
		var v := _team_views[i]
		var to: Vector3 = teams[i].p
		var off := to - v.position
		off.y = 0.0
		if off.length() > 0.05:
			v.rotation.y = lerp_angle(v.rotation.y, atan2(-off.x, -off.z), minf(delta * 6.0, 1.0))
		v.position = v.position.lerp(to, minf(delta * 3.0, 1.0))


## A plain crewman to stand about the boat: no tag, nothing to talk to.
func _sailor(look: Dictionary) -> Node3D:
	var v := Node3D.new()
	add_child(v)
	var body := Node3D.new()
	v.add_child(body)
	Crewman.build_body(body, look, Color.from_hsv(float(look.get("hue", 0.58)), 0.45, 0.85))
	var face := Node3D.new()
	face.position.y = Player.EYE_HEIGHT
	v.add_child(face)
	Crewman.build_face(face, look)
	Player._make_hat(face, look.get("hat", "watch"))
	return v


## The way a damage party walks between two points: along the middle of each room and through
## its doors and hatches, fewest rooms first. Each leg is {p, door}; door is the id of a door to
## go through there, or "". Goes through shut doors too: they open them as they get there.
func route(from: Vector3, to: Vector3) -> Array[Dictionary]:
	var hull := Sim.world.hull
	var out: Array[Dictionary] = []
	var here := hull.comp_at_pos(from)
	var last := hull.comp_at_pos(to)
	var up_tower := has_conning_tower and from.y > CT_FLOOR - 0.5
	if up_tower:
		_climb(out, true)
	else:
		out.append({"p": _on_centre(here, from.z), "door": ""})
	var came_from := {here: -1}
	var via := {}
	var edge: Array[int] = [here]
	while not edge.is_empty() and not came_from.has(last):
		var next: Array[int] = []
		for a: int in edge:
			for link: Array in _walk_links():
				for k in 2:
					if link[1 + k] != a or came_from.has(link[2 - k]):
						continue
					var b: int = link[2 - k]
					came_from[b] = a
					via[b] = link[0]
					next.append(b)
		edge = next
	var rooms: Array[int] = []
	var at := last
	while at != here and came_from.has(at):
		rooms.push_front(at)
		at = came_from[at]
	var was := here
	for r: int in rooms:
		var id: String = via[r]
		if id == "":
			_climb(out, compartments[r].get("y", 0.0) < compartments[was].get("y", 0.0))
		else:
			var dz := (doors[id] as Node3D).global_position.z
			out.append({"p": _on_centre(was, dz), "door": ""})
			out.append({"p": _floor_of((doors[id] as Node3D).global_position, was), "door": id})
			out.append({"p": _on_centre(r, dz), "door": ""})
		was = r
	out.append({"p": _on_centre(last, to.z), "door": ""})
	if has_conning_tower and to.y > CT_FLOOR - 0.5:
		_climb(out, false)
	return out


## The floor a damage party stands on to reach a point there.
func floor_at(p: Vector3) -> float:
	if has_conning_tower and p.y > CT_FLOOR - 0.5:
		return CT_FLOOR + 0.05
	return float(compartments[Sim.world.hull.comp_at_pos(p)].get("y", 0.0)) + 0.05


func _walk_links() -> Array:
	if not _room_links.is_empty():
		return _room_links
	var out: Array = []
	for id: String in door_links:
		out.append([id, door_links[id][0], door_links[id][1]])
	return out


func _on_centre(room: int, z: float) -> Vector3:
	var c := compartments[room]
	var z_in: float = clampf(z, float(c.z0) + 0.8, float(c.z1) - 0.8)
	return Vector3(c.get("x", 0.0), float(c.get("y", 0.0)) + 0.05, z_in)


func _floor_of(p: Vector3, room: int) -> Vector3:
	return Vector3(p.x, float(compartments[room].get("y", 0.0)) + 0.05, p.z)


## Up or down the ladder between decks.
func _climb(out: Array[Dictionary], down: bool) -> void:
	var path: Array = main_ladder.bottom_path.duplicate()
	if down:
		path.reverse()
	for q: Vector3 in path:
		out.append({"p": q, "door": ""})


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
