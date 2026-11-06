class_name HoloStation
extends Station
## The skipper's chair in the Typhoon's command bay (Blaney: a 3D view of what is happening in
## the water from everything the boat knows). Sit in it and H turns the hologram on or off; it
## floats in front of the chair and everyone aboard sees it (crew.holo, set by the host).
## Heading-up, our boat in the middle: the sea floor as glowing contour lines, ships and subs the
## boat can hear (sonar) or see (scope up or surfaced), and torpedoes in the water, ours blue,
## theirs red. Built facing -Z (the bow).

const RANGE := 8000.0 ## m from the middle to the edge
const RADIUS := 0.65 ## the hologram's radius in the room
const DEEP := 400.0 ## m of water shown top to bottom
const HEIGHT := 0.55
const GRID := 18 ## sea floor lines each way
const SEE := 12000.0 ## m a raised scope or the bridge can see ships
const BLUE := Color(0.31, 0.76, 1.0, 0.55)
const BRIGHT := Color(0.7, 0.92, 1.0, 0.9)
const ENEMY := Color(1.0, 0.3, 0.25, 0.9)

var seated := true
var _holo: Node3D
var _floor: MeshInstance3D
var _floor_at := Vector2(INF, INF)
var _floor_heading := INF
var _own: MeshInstance3D
var _marks: Array[MeshInstance3D] = []
var _tags: Array[Label3D] = []
var _drops: Array[MeshInstance3D] = []
var _mats := {}
var _timer := 0.0
var _lines: Array[Label] = []
var _shown := 0


func _ready() -> void:
	Build.cyl(self, 0.08, 0.5, Vector3(0, 0.25, 0), Color("#1E1E1E"))
	Build.box(self, Vector3(0.55, 0.1, 0.55), Vector3(0, 0.55, 0), Color("#5A3A2E"))
	Build.box(self, Vector3(0.55, 0.7, 0.1), Vector3(0, 0.95, 0.27), Color("#5A3A2E"))
	for side in [-1.0, 1.0]:
		Build.box(self, Vector3(0.08, 0.08, 0.45), Vector3(side * 0.28, 0.78, 0), Color("#1E1E1E"), false)
	Build.box(self, Vector3(0.12, 0.05, 0.1), Vector3(0.28, 0.83, -0.12), Color("#2E3A44"), false) # the switch on the arm
	Build.sphere(self, 0.02, Vector3(0.28, 0.87, -0.12), UiKit.GOOD, 2.0)
	Build.hitbox(self, Vector3(0.6, 1.3, 0.6), Vector3(0, 0.65, 0))
	# The projector: a ring in the deckhead over where the picture hangs.
	_holo = Node3D.new()
	_holo.position = Vector3(0.35, 1.45, -1.6)
	add_child(_holo)
	Build.cyl(self, 0.2, 0.06, Vector3(0.35, SubInterior.DECK_HEIGHT - 0.05, -1.6), Color("#2E3A44"), Vector3.UP)
	Build.sphere(self, 0.06, Vector3(0.35, SubInterior.DECK_HEIGHT - 0.09, -1.6), Color("#4FC3FF"), 2.0)
	_floor = MeshInstance3D.new()
	_holo.add_child(_floor)
	var rim := MeshInstance3D.new() # the sea surface's edge
	var torus := TorusMesh.new()
	torus.inner_radius = RADIUS - 0.01
	torus.outer_radius = RADIUS + 0.01
	rim.mesh = torus
	rim.material_override = _mat(BLUE)
	_holo.add_child(rim)
	_own = _box(Vector3(0.025, 0.02, 0.09), BRIGHT)
	_holo.visible = false
	set_view(Vector3(0, 1.22, 0.05), Vector3(0.35, 1.2, -1.6))
	bot_arms = Vector2(0.35, 0.35) # on the arm rests


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
	_holo.add_child(mi)
	return mi


## Where a point in the sea is drawn: heading-up, our boat in the middle.
func _place(p: Vector2, depth: float, sub: SubState) -> Vector3:
	var d := p - sub.pos
	var h := deg_to_rad(sub.heading)
	var fwd := d.dot(Vector2(sin(h), cos(h)))
	var right := d.dot(Vector2(cos(h), -sin(h)))
	return Vector3(right / RANGE * RADIUS, -minf(depth, DEEP) / DEEP * HEIGHT, -fwd / RANGE * RADIUS)


## What the boat knows is out there: [thing, depth, colour, name].
static func known(world: OceanWorld) -> Array:
	var sub := world.sub
	var out := []
	var heard := {}
	for c: Dictionary in SonarStation.contacts(sub):
		if c.c is ShipState:
			heard[c.c] = true
		elif c.c is Monster: # a shape in the dark, heard but not known
			out.append([c.c, c.c.depth, ENEMY, "?"])
	var looking := sub.is_surfaced() or (sub.periscope_raised and sub.depth <= sub.data.periscope_depth + 1.0)
	for s in world.ships:
		if s.is_sinking():
			continue
		var d := s.pos.distance_to(sub.pos)
		var seen := looking and s.depth < 1.0 and d < SEE
		if heard.has(s) or seen:
			out.append([s, s.depth, BRIGHT if seen else BLUE, s.data.display_name])
	for t in world.torpedoes:
		if t.alive and (not t.enemy or t.spotted or t.pos.distance_to(sub.pos) < 3000.0):
			out.append([t, t.depth, ENEMY if t.enemy else BRIGHT, ""])
	return out


func _process(delta: float) -> void:
	if Sim.world == null or Game.instance == null:
		return
	var on: bool = Game.instance.crew.get("holo", false)
	_holo.visible = on
	if overlay != null:
		_lines[0].text = "HOLOGRAM  %s   [H] %s" % ["ON" if on else "OFF", "turn it off" if on else "turn it on"]
		_lines[1].text = "%d contacts the boat knows of   range %d km   sea floor to %d m" % [_shown, roundi(RANGE / 1000.0), roundi(DEEP)]
	if not on or not is_visible_in_tree():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.25
	var w := Sim.world
	var sub := w.sub
	if sub.pos.distance_to(_floor_at) > 250.0 or absf(wrapf(sub.heading - _floor_heading, -180.0, 180.0)) > 4.0:
		_build_floor(w)
	_own.position = _place(sub.pos, sub.depth, sub)
	var things := known(w)
	_shown = things.size()
	while _marks.size() < things.size():
		_marks.append(_box(Vector3(0.03, 0.03, 0.03), BLUE))
		_drops.append(_box(Vector3(0.003, 1.0, 0.003), BLUE))
		var tag := Label3D.new()
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.font_size = 22
		tag.pixel_size = 0.0012
		tag.modulate = BRIGHT
		tag.no_depth_test = true
		_holo.add_child(tag)
		_tags.append(tag)
	for k in _marks.size():
		var on_k := k < things.size()
		_marks[k].visible = on_k
		_drops[k].visible = on_k
		_tags[k].visible = on_k
		if not on_k:
			continue
		var t: Array = things[k]
		var p := _place(t[0].pos, float(t[1]), sub)
		var outside := Vector2(p.x, p.z).length() > RADIUS
		if outside: # past the edge: pinned to the rim, on its bearing
			var flat := Vector2(p.x, p.z).normalized() * RADIUS
			p = Vector3(flat.x, p.y, flat.y)
		var torp: bool = t[0] is Torpedo
		var mark := _marks[k]
		(mark.mesh as BoxMesh).size = Vector3(0.012, 0.012, 0.03) if torp else Vector3(0.022, 0.018, 0.06)
		mark.material_override = _mat(t[2])
		mark.position = p
		mark.rotation.y = -deg_to_rad(t[0].heading - sub.heading)
		var drop := _drops[k] # a thin line up to the surface, so a sub's depth reads
		drop.visible = p.y < -0.01
		drop.scale.y = -p.y
		drop.position = Vector3(p.x, p.y * 0.5, p.z)
		_tags[k].text = "" if torp else "%s %.1f km" % [str(t[3]).to_lower(), t[0].pos.distance_to(sub.pos) / 1000.0]
		_tags[k].position = p + Vector3(0, 0.04, 0)


## The sea floor round the boat as a glowing grid of contour lines.
func _build_floor(w: OceanWorld) -> void:
	var sub := w.sub
	_floor_at = sub.pos
	_floor_heading = sub.heading
	var h := deg_to_rad(sub.heading)
	var fwd := Vector2(sin(h), cos(h))
	var right := Vector2(cos(h), -sin(h))
	var pts := []
	for j in GRID + 1:
		var row := []
		for i in GRID + 1:
			var u := lerpf(-1.0, 1.0, i / float(GRID))
			var v := lerpf(-1.0, 1.0, j / float(GRID))
			if Vector2(u, v).length() > 1.0:
				row.append(null)
				continue
			var p := sub.pos + right * u * RANGE + fwd * -v * RANGE
			row.append(Vector3(u * RADIUS, -minf(w.seabed.floor_depth(p), DEEP) / DEEP * HEIGHT, v * RADIUS))
		pts.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	for j in GRID + 1:
		for i in GRID + 1:
			var a: Variant = pts[j][i]
			if a == null:
				continue
			for n: Variant in [pts[j][i + 1] if i < GRID else null, pts[j + 1][i] if j < GRID else null]:
				if n != null:
					st.add_vertex(a)
					st.add_vertex(n)
	_floor.mesh = st.commit()
	_floor.material_override = _mat(BLUE)


func _build_overlay(root: Control) -> void:
	var box := UiKit.bottom_panel(root)
	box.add_child(UiKit.label("SKIPPER'S CHAIR", 22, UiKit.BRASS))
	_lines.clear()
	for i in 2:
		var l := UiKit.label()
		box.add_child(l)
		_lines.append(l)
	box.add_child(UiKit.label(footer(cluster != ""), 14, UiKit.DIM))


func station_input(event: InputEvent) -> void:
	if key_pressed(event, KEY_H) and not event.echo:
		order("holo")
		click()
