class_name HoloView
extends Node3D
## A hologram of the water round the boat (Blaney: the navigation room is mostly a giant
## hologram showing every piece of information, for testing, even what the boat hasn't found;
## then: "doesn't really give any perspective toward where the sub is relative to the different
## locations ... should be more detailed and clear and not difficult to see or understand.
## detailed images of the monsters should also show up and a close up view of around the ship
## should be an option to toggle").
## Heading-up, our boat in the middle as a bright little submarine with a beacon up through the
## surface and a pulsing ring round her; range rings marked in km (m close up) and the compass
## points round the rim, so where anything lies and how far reads at a glance; a line out from
## her across the surface to every place and the waypoint, each labelled with its bearing and
## range; the sea floor a shaded relief (shallow green, deep blue) under a sparse grid; ships
## as arrowheads pointing where they steam; every monster as a small glowing copy of itself,
## and the nearest one big over the far rim with its name. What the boat knows of (`known`) is
## bright; the rest are dim ghosts that flicker (Blaney: "a little unsettling"), and the whole
## picture runs colder and dimmer the deeper she is. `close_up` (Z in the captain's chair)
## shows the 600 m round her instead of 12 km: the sea floor under her, the places close by,
## a monster at its real size against her.
## Used in the navigation room (`radius` ~1.2 m) and full screen from the captain's chair
## (`screen`). Built facing -Z (the bow).

const BLUE := Color(0.31, 0.76, 1.0, 0.55)
const BRIGHT := Color(0.7, 0.95, 1.0, 0.95)
const OWN := Color(0.45, 1.0, 0.85, 1.0)
const ENEMY := Color(1.0, 0.3, 0.25, 0.95)
const MONSTER := Color(1.0, 0.45, 0.2, 0.9)
const GHOST := Color(0.45, 0.6, 0.85, 0.16)
const RING := Color(0.31, 0.76, 1.0, 0.28)
const SITE_COLS := {"garden": Color(0.5, 1.0, 0.7, 0.85), "wreck": Color(0.95, 0.8, 0.5, 0.85), "ruins": Color(0.9, 0.9, 0.7, 0.85),
	"vents": Color(1.0, 0.6, 0.3, 0.9), "alien": Color(0.85, 0.5, 1.0, 0.95), "island": Color(0.6, 0.95, 0.6, 0.75), "cave": Color(0.75, 0.75, 1.0, 0.8)}
const SEE := 12000.0 ## m a raised scope or the bridge can see ships
const FAR := 12000.0 ## m to the rim normally
const NEAR := 600.0 ## m to the rim close up

static var close_up := false ## Z in the captain's chair: the 600 m round her (every hologram aboard)

var radius := 1.2 ## the hologram's radius in the room
var height := 1.0 ## top (the surface) to the deepest it shows
var range_m := FAR ## m from the middle to the edge
var deep := 600.0 ## m of water shown top to bottom
var grid := 12 ## sea floor lines each way
var cells := 40 ## the shaded floor's cells each way
var labels := true
var label_size := 0.0016
var _floor: MeshInstance3D
var _floor_lines: MeshInstance3D
var _rim: MeshInstance3D
var _rings: MeshInstance3D
var _ring_tags: Array[Label3D] = []
var _compass: Array[Label3D] = []
var _spokes: MeshInstance3D
var _floor_at := Vector2(INF, INF)
var _floor_heading := INF
var _floor_version := -1
var _floor_range := 0.0
var _own: Node3D
var _own_ring: MeshInstance3D
var _beacon: MeshInstance3D
var _own_tag: Label3D
var _marks: Array[MeshInstance3D] = []
var _tags: Array[Label3D] = []
var _drops: Array[MeshInstance3D] = []
var _beasts := {} ## monster id -> its small hologram copy
var _show_beast: Node3D ## the nearest monster, big over the far rim
var _show_kind := ""
var _show_tag: Label3D
var _mats := {}
var _timer := 0.0
var _wobble := 0.0
var _arrow: Mesh
var shown := 0 ## things drawn last time
var ghosts := 0 ## of them, ones the boat doesn't know of


## The hologram full on a screen: a SubViewport of its own with a camera looking down on it.
static func screen(_all := true) -> Control:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	box.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.01, 0.025, 0.05)
	env.environment.glow_enabled = true
	vp.add_child(env)
	var h := HoloView.new()
	h.radius = 1.0
	h.height = 0.55
	h.label_size = 0.0021
	vp.add_child(h)
	var cam := Camera3D.new()
	cam.fov = 50.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 2.25, 2.0), Vector3(0, -0.75, 0.15)) # the disc in the top part, clear of the chair's panel
	return box


func _ready() -> void:
	_arrow = _arrow_mesh()
	_floor = MeshInstance3D.new()
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.vertex_color_use_as_albedo = true
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fm.no_depth_test = false
	_floor.material_override = fm
	add_child(_floor)
	_floor_lines = MeshInstance3D.new()
	add_child(_floor_lines)
	_rim = MeshInstance3D.new() # the sea surface's edge
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.01
	torus.outer_radius = radius + 0.01
	_rim.mesh = torus
	_rim.material_override = _mat(BLUE)
	add_child(_rim)
	_rings = MeshInstance3D.new()
	_rings.material_override = _mat(RING)
	add_child(_rings)
	_spokes = MeshInstance3D.new()
	_spokes.material_override = _mat(Color(0.5, 0.9, 1.0, 0.35))
	add_child(_spokes)
	for i in 4:
		_ring_tags.append(_label(18, Color(0.55, 0.85, 1.0, 0.7)))
	for n in ["N", "E", "S", "W"]:
		var c := _label(30, Color(0.8, 0.95, 1.0, 0.9) if n == "N" else Color(0.55, 0.8, 1.0, 0.7))
		c.text = n
		_compass.append(c)
	_own = _sub_shape(OWN)
	add_child(_own)
	_own_ring = MeshInstance3D.new()
	var ot := TorusMesh.new()
	ot.inner_radius = 0.95
	ot.outer_radius = 1.0
	_own_ring.mesh = ot
	_own_ring.material_override = _mat(Color(OWN, 0.6))
	add_child(_own_ring)
	_beacon = MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.004 * radius
	bc.bottom_radius = 0.004 * radius
	bc.height = 1.0
	_beacon.mesh = bc
	_beacon.material_override = _mat(Color(OWN, 0.55))
	add_child(_beacon)
	_own_tag = _label(26, OWN)
	_own_tag.text = "US"
	_show_tag = _label(26, MONSTER)


func _label(size: int, c: Color) -> Label3D:
	var tag := Label3D.new()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = size
	tag.outline_size = 8
	tag.outline_modulate = Color(0.0, 0.03, 0.08, 0.85)
	tag.pixel_size = label_size
	tag.no_depth_test = true
	tag.modulate = c
	add_child(tag)
	return tag


func _mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = c
		_mats[key] = m
	return _mats[key]


## An arrowhead pointing -Z, 1 long: a ship, steaming where it points.
static func _arrow_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip := Vector3(0, 0, -0.5)
	var l := Vector3(-0.32, 0, 0.5)
	var r := Vector3(0.32, 0, 0.5)
	var back := Vector3(0, 0, 0.25)
	var top := Vector3(0, 0.18, 0.1)
	for t: Array in [[tip, l, top], [tip, top, r], [l, back, top], [back, r, top], [tip, back, l], [tip, r, back]]:
		for v: Vector3 in t:
			st.add_vertex(v)
	return st.commit()


## A little submarine 1 long, nose to -Z: a cigar with a fin.
func _sub_shape(c: Color) -> Node3D:
	var n := Node3D.new()
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.09
	cap.height = 1.0
	cap.radial_segments = 12
	body.mesh = cap
	body.rotation.x = PI * 0.5
	body.material_override = _mat(c)
	n.add_child(body)
	var fin := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(0.05, 0.12, 0.18)
	fin.mesh = fb
	fin.position = Vector3(0, 0.12, -0.08)
	fin.material_override = _mat(c)
	n.add_child(fin)
	return n


## A monster's own shape, glowing: its model with the hologram's light for paint.
func _beast(kind: String, size: float, c: Color) -> Node3D:
	var b := Creatures.monster(kind, Monster.KINDS[kind].length)
	b.scale = Vector3.ONE * (size / float(Monster.KINDS[kind].length))
	for m in b.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = _mat(c)
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(b)
	return b


func _box(size: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	add_child(mi)
	return mi


## Where a point in the sea is drawn: heading-up, our boat in the middle.
func place(p: Vector2, depth: float, sub: SubState) -> Vector3:
	var d := p - sub.pos
	var h := deg_to_rad(sub.heading)
	var fwd := d.dot(Vector2(sin(h), cos(h)))
	var right := d.dot(Vector2(cos(h), -sin(h)))
	return Vector3(right / range_m * radius, -minf(depth, deep) / deep * height, -fwd / range_m * radius)


## What the boat knows is out there (heard on sonar, or seen with the scope up or surfaced).
static func known(world: OceanWorld) -> Dictionary:
	var sub := world.sub
	var out := {}
	for c: Dictionary in SonarStation.contacts(sub):
		out[c.c] = true
	var looking := sub.is_surfaced() or (sub.periscope_raised and sub.depth <= sub.data.periscope_depth + 1.0)
	for s in world.ships:
		if looking and s.depth < 1.0 and s.pos.distance_to(sub.pos) < SEE:
			out[s] = true
	for t in world.torpedoes:
		if not t.enemy or t.spotted or t.pos.distance_to(sub.pos) < 3000.0:
			out[t] = true
	return out


## Everything there is: [thing, pos, depth, colour, name, size (box) or "arrow", known, line out to it].
func _everything(w: OceanWorld) -> Array:
	var sub := w.sub
	var k := known(w)
	var out := []
	for s in w.ships:
		var what := "%s, %s %d kn%s" % [s.data.display_name, "sinking" if s.is_sinking() else ShipAI.MODE_NAMES[clampi(s.mode, 0, 4)], roundi(s.speed * 1.94384),
			", %d m" % roundi(s.depth) if s.depth > 1.0 else ""]
		out.append([s, s.pos, s.depth, ENEMY if s.data.role == "sub" else BLUE, what, "arrow", k.has(s), false])
	for t in w.torpedoes:
		if t.alive:
			out.append([t, t.pos, t.depth, ENEMY if t.enemy else BRIGHT, "", Vector3(0.008, 0.008, 0.03) * radius, k.has(t), false])
	for c in w.charges:
		out.append([c, c.pos, c.depth, ENEMY, "", Vector3.ONE * 0.012 * radius, true, false])
	for wh in w.whales:
		out.append([wh, wh.pos, wh.depth, Color(0.6, 0.85, 1.0, 0.7), "whale%s" % (", singing" if wh.singing else ""), Vector3(0.016, 0.01, 0.04) * radius, k.has(wh), false])
	for m in w.monsters:
		if m.state != "dead":
			out.append([m, m.pos, m.depth, MONSTER, "%s, %s, %d m" % [m.info().name.to_upper(), Monster.STATE_NAMES.get(m.state, m.state), roundi(m.depth)], "beast", k.has(m), false])
	for p in w.planes:
		out.append([p, p.pos, -0.12 / height * deep, Color(1.0, 0.85, 0.5, 0.8), "plane", Vector3(0.03, 0.006, 0.02) * radius, sub.is_surfaced() or sub.periscope_raised, false])
	for pl: Dictionary in Places.list(w.seabed):
		out.append([null, Places.pos(pl), maxf(float(pl.depth), 0.0), SITE_COLS.get(pl.kind, BLUE), "%s%s" % [pl.name, ", %d m down" % roundi(float(pl.depth)) if float(pl.depth) > 0.0 else ""],
			Vector3.ONE * 0.026 * radius, true, true])
	var wp: Dictionary = Game.instance.crew.get("waypoint", {}) if Game.instance != null else {}
	if not wp.is_empty():
		out.append([null, Vector2(wp.x, wp.y), 0.0, UiKit.GOOD, "WAYPOINT: %s" % wp.name, Vector3(0.008, 0.2, 0.008) * radius, true, true])
	return out


func _process(delta: float) -> void:
	if Sim.world == null or not is_visible_in_tree():
		return
	_wobble += delta
	var pulse := 0.5 + 0.5 * sin(_wobble * 3.0)
	_own_ring.scale = Vector3.ONE * radius * lerpf(0.035, 0.06, pulse)
	_own_ring.material_override = _mat(Color(OWN, lerpf(0.7, 0.2, pulse)))
	if _show_beast != null:
		_show_beast.rotation.y += delta * 0.4
	_timer -= delta
	if _timer > 0.0:
		_flicker()
		return
	_timer = 0.2
	var w := Sim.world
	var sub := w.sub
	range_m = NEAR if close_up else FAR
	deep = maxf(sub.depth * 2.0 + 60.0, 200.0) if close_up else 600.0
	# Colder and dimmer the deeper she is.
	var dread := clampf(sub.depth / maxf(sub.data.test_depth, 50.0), 0.0, 1.0)
	_rim.material_override = _mat(BLUE.lerp(Color(0.25, 0.35, 0.8, 0.35), dread))
	if sub.pos.distance_to(_floor_at) > range_m / 30.0 or absf(wrapf(sub.heading - _floor_heading, -180.0, 180.0)) > 4.0 \
			or w.seabed.version != _floor_version or _floor_range != range_m:
		_build_floor(w, dread)
	_draw_frame(sub)
	var at := place(sub.pos, sub.depth, sub)
	_own.position = at
	_own.scale = Vector3.ONE * 0.09 * radius
	_own_ring.position = Vector3(0, 0.002, 0)
	_beacon.position = Vector3(0, at.y * 0.5 + 0.06 * radius, 0)
	_beacon.scale = Vector3(1, -at.y + 0.12 * radius, 1)
	_own_tag.text = "US  %d m" % roundi(sub.depth)
	_own_tag.pixel_size = label_size * 1.1
	_own_tag.position = Vector3(0, 0.13 * radius, 0)
	var things := _everything(w)
	shown = things.size()
	ghosts = 0
	while _marks.size() < things.size():
		_marks.append(_box(Vector3.ONE, BLUE))
		_drops.append(_box(Vector3(0.0025, 1.0, 0.0025) * radius, BLUE))
		_tags.append(_label(24, BLUE))
	var spokes := []
	var seen_beasts := {}
	var nearest: Monster = null
	for i in _marks.size():
		var on := i < things.size()
		_marks[i].visible = on
		_drops[i].visible = on
		_tags[i].visible = on and labels
		if not on:
			continue
		var t: Array = things[i]
		var p := place(t[1], float(t[2]), sub)
		var r: float = (t[1] as Vector2).distance_to(sub.pos)
		var past := Vector2(p.x, p.z).length() > radius
		if past: # past the edge: pinned to the rim, on its bearing
			var flat := Vector2(p.x, p.z).normalized() * radius
			p = Vector3(flat.x, p.y, flat.y)
		var col: Color = t[3]
		var seen: bool = t[6]
		if not seen:
			ghosts += 1
			col = GHOST
		col = col.lerp(Color(col.r * 0.6, col.g * 0.7, col.b, col.a * 0.8), dread)
		var mark := _marks[i]
		mark.set_meta("ghost", not seen)
		mark.set_meta("at", p)
		var heading: float = t[0].heading if t[0] != null and "heading" in t[0] else sub.heading
		mark.rotation.y = -deg_to_rad(heading - sub.heading)
		mark.position = p
		if t[5] is Vector3:
			mark.mesh = _cube()
			mark.scale = t[5]
		elif str(t[5]) == "arrow":
			mark.mesh = _arrow
			var big := clampf((t[0] as ShipState).data.length / 150.0, 0.6, 1.5)
			mark.scale = Vector3.ONE * radius * (0.035 if past else (0.05 if not close_up else maxf(0.05, (t[0] as ShipState).data.length / range_m))) * big
		else: # a monster: its own shape, glowing
			mark.visible = false
			mark.mesh = null
			var m := t[0] as Monster
			seen_beasts[m.id] = true
			var b: Node3D = _beasts.get(m.id)
			if b == null:
				b = _beast(m.kind, 1.0, MONSTER)
				_beasts[m.id] = b
			var size := maxf(m.length() / range_m * radius, 0.09 * radius) # life size close up, never too small to see
			b.scale = Vector3.ONE * (size / m.length())
			b.position = p
			b.rotation.y = mark.rotation.y
			b.visible = not (not seen and fmod(_wobble * 3.0 + i, 3.0) < 0.4)
			for mi in b.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_override = _mat(col)
			if nearest == null or m.pos.distance_to(sub.pos) < nearest.pos.distance_to(sub.pos):
				nearest = m
		mark.material_override = _mat(col)
		var drop := _drops[i] # a thin line up to the surface, so a depth reads
		drop.visible = p.y < -0.01
		drop.scale.y = -p.y / radius
		drop.position = Vector3(p.x, p.y * 0.5, p.z)
		drop.material_override = _mat(Color(col, col.a * 0.45))
		if t[7]: # a line out from us across the surface to it, so where it lies reads at once
			spokes.append([Vector3(p.x, 0.0, p.z), col])
		var tag := _tags[i]
		var brg := roundi(ShipState.bearing(sub.pos, t[1])) % 360
		var dist := ("%.1f km" % (r / 1000.0)) if r >= 1000.0 else ("%d m" % roundi(r))
		var quiet: bool = (past and not t[7]) or (not seen and t[0] is Whale) # nothing far off but places; no ghost whales
		tag.text = "" if str(t[4]) == "" or quiet else "%s%s\n%03d°  %s%s" % ["? " if not seen else "", str(t[4]), brg, dist, "  ▶" if past else ""]
		tag.modulate = Color(col, 0.95 if seen else 0.35)
		tag.pixel_size = label_size * (0.75 if past else 1.0) # far-off places on the rim are smaller: what's near reads first
		tag.position = p + Vector3(0, 0.05 * radius, 0) * (1.0 if not past else 1.0 + 0.6 * float(i % 3)) # stagger the rim's labels
	for id: int in _beasts.keys():
		if not seen_beasts.has(id):
			_beasts[id].queue_free()
			_beasts.erase(id)
	_draw_spokes(spokes)
	_feature(nearest, sub)


static var _cube_mesh: BoxMesh
static func _cube() -> BoxMesh:
	if _cube_mesh == null:
		_cube_mesh = BoxMesh.new()
	return _cube_mesh


## The nearest monster, big and turning slowly over the far rim, with its name and what it's doing.
func _feature(m: Monster, sub: SubState) -> void:
	if m == null:
		if _show_beast != null:
			_show_beast.queue_free()
			_show_beast = null
			_show_kind = ""
		_show_tag.visible = false
		return
	if _show_kind != m.kind:
		if _show_beast != null:
			_show_beast.queue_free()
		_show_beast = _beast(m.kind, 0.5 * radius, Color(MONSTER, 0.35))
		_show_kind = m.kind
	_show_beast.position = Vector3(-radius * 1.05, 0.12 * radius, -radius * 0.2) # off the port beam, over the rim
	_show_tag.visible = labels
	_show_tag.pixel_size = label_size * 1.2
	_show_tag.position = _show_beast.position + Vector3(0, 0.2 * radius, 0)
	var r := m.pos.distance_to(sub.pos)
	_show_tag.text = "%s — %d m long\n%s, %s off, %d m down" % [m.info().name.to_upper(), roundi(m.length()), Monster.STATE_NAMES.get(m.state, m.state),
		("%.1f km" % (r / 1000.0)) if r >= 1000.0 else ("%d m" % roundi(r)), roundi(m.depth)]


## Range rings on the surface with their distances, the bow line, and the compass round the rim.
func _draw_frame(sub: SubState) -> void:
	var step := range_m / 4.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	for k in range(1, 4):
		var rr := radius * k / 4.0
		for j in 64:
			var a0 := TAU * j / 64.0
			var a1 := TAU * (j + 1) / 64.0
			st.add_vertex(Vector3(cos(a0) * rr, 0, sin(a0) * rr))
			st.add_vertex(Vector3(cos(a1) * rr, 0, sin(a1) * rr))
	st.add_vertex(Vector3.ZERO) # the bow line, dead ahead
	st.add_vertex(Vector3(0, 0, -radius))
	_rings.mesh = st.commit()
	for k in 4:
		var d := step * (k + 1)
		_ring_tags[k].text = (("%d km" if is_equal_approx(d / 1000.0, roundf(d / 1000.0)) else "%.1f km") % (d / 1000.0)) if d >= 1000.0 else ("%d m" % roundi(d))
		_ring_tags[k].pixel_size = label_size * 0.9
		_ring_tags[k].position = Vector3(0.7071, 0, 0.7071) * radius * (k + 1) / 4.0 + Vector3(0, 0.02, 0)
	var h := deg_to_rad(sub.heading)
	for k in 4: # N E S W: a true bearing k * 90 drawn heading-up
		var b := deg_to_rad(k * 90.0) - h
		_compass[k].position = Vector3(sin(b), 0.0, -cos(b)) * radius * 1.08 + Vector3(0, 0.02, 0)
		_compass[k].pixel_size = label_size * 1.3


func _draw_spokes(spokes: Array) -> void:
	if spokes.is_empty():
		_spokes.mesh = null
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	for s: Array in spokes:
		var to: Vector3 = s[0]
		var n := maxi(2, int(to.length() / (0.04 * radius)))
		for k in n: # dashed
			if k % 2 == 1:
				continue
			st.set_color(s[1])
			st.add_vertex(to * float(k) / n)
			st.set_color(s[1])
			st.add_vertex(to * float(k + 1) / n)
	var m := st.commit()
	_spokes.mesh = m
	var mat := _mat(Color(1, 1, 1, 0.45)).duplicate() as StandardMaterial3D
	mat.vertex_color_use_as_albedo = true
	_spokes.material_override = mat


## The ghosts never sit still: they flicker and drift a little, between the 5-a-second updates.
func _flicker() -> void:
	for i in _marks.size():
		var m := _marks[i]
		if not m.get_meta("ghost", false) or i >= shown:
			continue
		var at: Vector3 = m.get_meta("at")
		var n := sin(_wobble * 7.0 + i * 1.7) * sin(_wobble * 2.3 + i)
		m.visible = n > -0.85 and m.mesh != null # now and then it's not there at all
		m.position = at + Vector3(sin(_wobble * 1.3 + i), 0.0, cos(_wobble * 1.1 + i * 2.0)) * 0.012 * radius
		_tags[i].visible = labels and n > -0.5


## The sea floor round the boat: shaded by depth (shallow green, deep blue, the deepest dark)
## under a sparse glowing grid.
func _build_floor(w: OceanWorld, dread: float) -> void:
	var sub := w.sub
	_floor_at = sub.pos
	_floor_heading = sub.heading
	_floor_version = w.seabed.version
	_floor_range = range_m
	var h := deg_to_rad(sub.heading)
	var fwd := Vector2(sin(h), cos(h))
	var right := Vector2(cos(h), -sin(h))
	var n := cells
	var pts := []
	var cols := []
	for j in n + 1:
		var row := []
		var crow := []
		for i in n + 1:
			var u := lerpf(-1.0, 1.0, i / float(n))
			var v := lerpf(-1.0, 1.0, j / float(n))
			if Vector2(u, v).length() > 1.04:
				row.append(null)
				crow.append(null)
				continue
			var p := sub.pos + right * u * range_m + fwd * -v * range_m
			var d := clampf(w.seabed.floor_depth(p, true), 0.0, deep)
			row.append(Vector3(u * radius, -d / deep * height, v * radius))
			var t := clampf(d / deep, 0.0, 1.0)
			var c := Color(0.35, 1.0, 0.6).lerp(Color(0.15, 0.5, 1.0), smoothstep(0.0, 0.35, t)).lerp(Color(0.1, 0.15, 0.45), smoothstep(0.35, 1.0, t))
			crow.append(Color(c * lerpf(1.0, 0.6, dread), 0.22))
		pts.append(row)
		cols.append(crow)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n:
		for i in n:
			var q: Array = [pts[j][i], pts[j][i + 1], pts[j + 1][i + 1], pts[j + 1][i]]
			var qc: Array = [cols[j][i], cols[j][i + 1], cols[j + 1][i + 1], cols[j + 1][i]]
			if q.has(null):
				continue
			for k: int in [0, 1, 2, 0, 2, 3]:
				st.set_color(qc[k])
				st.add_vertex(q[k])
	_floor.mesh = st.commit()
	var lines := SurfaceTool.new()
	lines.begin(Mesh.PRIMITIVE_LINES)
	var every := maxi(1, n / grid)
	for j in range(0, n + 1, every):
		for i in range(0, n + 1, every):
			var a: Variant = pts[j][i]
			if a == null:
				continue
			for o: Variant in [pts[j][i + every] if i + every <= n else null, pts[j + every][i] if j + every <= n else null]:
				if o != null:
					lines.add_vertex(a)
					lines.add_vertex(o)
	_floor_lines.mesh = lines.commit()
	_floor_lines.material_override = _mat(BLUE.lerp(Color(0.2, 0.3, 0.7, 0.3), dread) * Color(1, 1, 1, 0.5))
