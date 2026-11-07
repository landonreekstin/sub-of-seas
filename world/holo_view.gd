class_name HoloView
extends Node3D
## A hologram of the water round the boat (Blaney: the navigation room is mostly a giant
## hologram showing every piece of information, for testing, even what the boat hasn't found).
## Heading-up, our boat in the middle: the sea floor as glowing grid lines, every ship, sub,
## whale, monster, plane, torpedo and charge, the places on the sea floor, the cave and the
## waypoint, each with its name and what it's doing. What the boat knows of (`known`) is bright;
## the rest are dim ghosts that flicker and drift (Blaney: "a little unsettling"), and the whole
## picture runs colder and dimmer the deeper she is (the deeper, the more unsettling).
## Used in the navigation room (`radius` ~1.2 m) and full screen from the captain's chair
## (`screen`). Built facing -Z (the bow).

const BLUE := Color(0.31, 0.76, 1.0, 0.55)
const BRIGHT := Color(0.7, 0.92, 1.0, 0.9)
const ENEMY := Color(1.0, 0.3, 0.25, 0.9)
const GHOST := Color(0.45, 0.6, 0.85, 0.22)
const SITE_COLS := {"garden": Color(0.5, 1.0, 0.7, 0.8), "wreck": Color(0.9, 0.75, 0.5, 0.8), "ruins": Color(0.85, 0.85, 0.7, 0.8),
	"vents": Color(1.0, 0.55, 0.25, 0.85), "alien": Color(0.8, 0.45, 1.0, 0.9), "island": Color(0.6, 0.9, 0.6, 0.6), "cave": Color(0.7, 0.7, 0.9, 0.7)}
const SEE := 12000.0 ## m a raised scope or the bridge can see ships

var radius := 1.2 ## the hologram's radius in the room
var height := 1.0 ## top (the surface) to the deepest it shows
var range_m := 10000.0 ## m from the middle to the edge
var deep := 600.0 ## m of water shown top to bottom
var grid := 24 ## sea floor lines each way
var labels := true
var label_size := 0.0016
var _floor: MeshInstance3D
var _rim: MeshInstance3D
var _floor_at := Vector2(INF, INF)
var _floor_heading := INF
var _floor_version := -1
var _own: MeshInstance3D
var _marks: Array[MeshInstance3D] = []
var _tags: Array[Label3D] = []
var _drops: Array[MeshInstance3D] = []
var _mats := {}
var _timer := 0.0
var _wobble := 0.0
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
	h.height = 0.7
	h.range_m = 12000.0
	h.label_size = 0.0022
	vp.add_child(h)
	var cam := Camera3D.new()
	cam.fov = 50.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.45, 1.75), Vector3(0, -0.2, 0))
	return box


func _ready() -> void:
	_floor = MeshInstance3D.new()
	add_child(_floor)
	_rim = MeshInstance3D.new() # the sea surface's edge
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.012
	torus.outer_radius = radius + 0.012
	_rim.mesh = torus
	_rim.material_override = _mat(BLUE)
	add_child(_rim)
	_own = _box(Vector3(0.035, 0.03, 0.12) * radius / 0.65 * 0.5, BRIGHT)


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


## Everything there is: [thing, pos, depth, colour, name, size (box), known].
func _everything(w: OceanWorld) -> Array:
	var sub := w.sub
	var k := known(w)
	var out := []
	for s in w.ships:
		var what := "%s %s %d kn%s" % [s.data.display_name, "sinking" if s.is_sinking() else ShipAI.MODE_NAMES[clampi(s.mode, 0, 4)], roundi(s.speed * 1.94384),
			" %d m" % roundi(s.depth) if s.depth > 1.0 else ""]
		out.append([s, s.pos, s.depth, ENEMY if s.data.role == "sub" else BLUE, what, Vector3(0.022, 0.018, 0.06), k.has(s)])
	for t in w.torpedoes:
		if t.alive:
			out.append([t, t.pos, t.depth, ENEMY if t.enemy else BRIGHT, "", Vector3(0.012, 0.012, 0.03), k.has(t)])
	for c in w.charges:
		out.append([c, c.pos, c.depth, ENEMY, "", Vector3(0.012, 0.012, 0.012), true])
	for wh in w.whales:
		out.append([wh, wh.pos, wh.depth, Color(0.6, 0.85, 1.0, 0.7), "whale %s" % ("singing" if wh.singing else ""), Vector3(0.02, 0.012, 0.045), k.has(wh)])
	for m in w.monsters:
		if m.state != "dead":
			out.append([m, m.pos, m.depth, ENEMY, "%s %s" % [m.kind, m.state], Vector3(0.035, 0.03, 0.07), k.has(m)])
	for p in w.planes:
		out.append([p, p.pos, -0.12 / height * deep, Color(1.0, 0.85, 0.5, 0.8), "plane", Vector3(0.03, 0.006, 0.02), sub.is_surfaced() or sub.periscope_raised])
	for pl: Dictionary in Places.list(w.seabed):
		out.append([null, Places.pos(pl), maxf(float(pl.depth), 0.0), SITE_COLS.get(pl.kind, BLUE), "%s %s" % [pl.name, "%d m" % roundi(float(pl.depth)) if float(pl.depth) > 0.0 else ""],
			Vector3(0.03, 0.03, 0.03), true])
	var wp: Dictionary = Game.instance.crew.get("waypoint", {}) if Game.instance != null else {}
	if not wp.is_empty():
		out.append([null, Vector2(wp.x, wp.y), 0.0, UiKit.GOOD, "WAYPOINT %s" % wp.name, Vector3(0.008, 0.25, 0.008), true])
	return out


func _process(delta: float) -> void:
	if Sim.world == null or not is_visible_in_tree():
		return
	_wobble += delta
	_timer -= delta
	if _timer > 0.0:
		_flicker()
		return
	_timer = 0.2
	var w := Sim.world
	var sub := w.sub
	# Colder and dimmer the deeper she is.
	var dread := clampf(sub.depth / maxf(sub.data.test_depth, 50.0), 0.0, 1.0)
	_rim.material_override = _mat(BLUE.lerp(Color(0.25, 0.35, 0.8, 0.35), dread))
	if sub.pos.distance_to(_floor_at) > range_m / 30.0 or absf(wrapf(sub.heading - _floor_heading, -180.0, 180.0)) > 4.0 or w.seabed.version != _floor_version:
		_build_floor(w, dread)
	_own.position = place(sub.pos, sub.depth, sub)
	var things := _everything(w)
	shown = things.size()
	ghosts = 0
	while _marks.size() < things.size():
		_marks.append(_box(Vector3(0.03, 0.03, 0.03), BLUE))
		_drops.append(_box(Vector3(0.003, 1.0, 0.003), BLUE))
		var tag := Label3D.new()
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.font_size = 22
		tag.pixel_size = label_size
		tag.no_depth_test = true
		add_child(tag)
		_tags.append(tag)
	for i in _marks.size():
		var on := i < things.size()
		_marks[i].visible = on
		_drops[i].visible = on
		_tags[i].visible = on and labels
		if not on:
			continue
		var t: Array = things[i]
		var p := place(t[1], float(t[2]), sub)
		if Vector2(p.x, p.z).length() > radius: # past the edge: pinned to the rim, on its bearing
			var flat := Vector2(p.x, p.z).normalized() * radius
			p = Vector3(flat.x, p.y, flat.y)
		var col: Color = t[3]
		var seen: bool = t[6]
		if not seen:
			ghosts += 1
			col = GHOST
		col = col.lerp(Color(col.r * 0.6, col.g * 0.7, col.b, col.a * 0.8), dread)
		var mark := _marks[i]
		(mark.mesh as BoxMesh).size = t[5] * radius / 0.65 * 0.5
		mark.material_override = _mat(col)
		mark.position = p
		mark.set_meta("ghost", not seen)
		mark.set_meta("at", p)
		mark.rotation.y = -deg_to_rad(t[0].heading - sub.heading) if t[0] != null and "heading" in t[0] else 0.0
		var drop := _drops[i] # a thin line up to the surface, so a depth reads
		drop.visible = p.y < -0.01
		drop.scale.y = -p.y
		drop.position = Vector3(p.x, p.y * 0.5, p.z)
		drop.material_override = _mat(Color(col, col.a * 0.5))
		var tag := _tags[i]
		var r: float = (t[1] as Vector2).distance_to(sub.pos)
		tag.text = "" if str(t[4]) == "" else "%s%s %.1f km" % ["? " if not seen else "", str(t[4]).to_lower(), r / 1000.0]
		tag.modulate = Color(col, 0.95 if seen else 0.4)
		tag.position = p + Vector3(0, 0.04 * radius, 0)


## The ghosts never sit still: they flicker and drift a little, between the 5-a-second updates.
func _flicker() -> void:
	for i in _marks.size():
		var m := _marks[i]
		if not m.visible or not m.get_meta("ghost", false):
			continue
		var at: Vector3 = m.get_meta("at")
		var n := sin(_wobble * 7.0 + i * 1.7) * sin(_wobble * 2.3 + i)
		m.visible = n > -0.85 # now and then it's not there at all
		m.position = at + Vector3(sin(_wobble * 1.3 + i), 0.0, cos(_wobble * 1.1 + i * 2.0)) * 0.012 * radius
		_tags[i].visible = labels and n > -0.5


## The sea floor round the boat as a glowing grid.
func _build_floor(w: OceanWorld, dread: float) -> void:
	var sub := w.sub
	_floor_at = sub.pos
	_floor_heading = sub.heading
	_floor_version = w.seabed.version
	var h := deg_to_rad(sub.heading)
	var fwd := Vector2(sin(h), cos(h))
	var right := Vector2(cos(h), -sin(h))
	var pts := []
	for j in grid + 1:
		var row := []
		for i in grid + 1:
			var u := lerpf(-1.0, 1.0, i / float(grid))
			var v := lerpf(-1.0, 1.0, j / float(grid))
			if Vector2(u, v).length() > 1.0:
				row.append(null)
				continue
			var p := sub.pos + right * u * range_m + fwd * -v * range_m
			row.append(Vector3(u * radius, -clampf(w.seabed.floor_depth(p, true), 0.0, deep) / deep * height, v * radius))
		pts.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	for j in grid + 1:
		for i in grid + 1:
			var a: Variant = pts[j][i]
			if a == null:
				continue
			for n: Variant in [pts[j][i + 1] if i < grid else null, pts[j + 1][i] if j < grid else null]:
				if n != null:
					st.add_vertex(a)
					st.add_vertex(n)
	_floor.mesh = st.commit()
	_floor.material_override = _mat(BLUE.lerp(Color(0.2, 0.3, 0.7, 0.35), dread))
