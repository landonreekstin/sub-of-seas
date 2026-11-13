class_name CameraStation
extends Station
## The camera bank in the navigation room (Blaney: "cameras around the outside of the sub,
## there should be a viewing center"; "more outside cameras from a variety of angles but laid
## out in an intuitive way. if you click on the screen it should show what part of the sub that
## particular video screen is on"). Twelve cameras on our own boat in the ocean outside, their
## screens laid out like a map of her seen from above as you face the port side: bow to the
## right, as she really lies, the port cameras along the top, starboard along the bottom, stern
## and bow at the ends of a drawing of her in the middle, each joined to a dot where it sits.
## The small screens take turns rendering while someone is near; man the console and click a
## screen (or press its key) to put it on the big one, which shows her outline with a red dot
## at that camera.

## [label, kind, key, column, row]: columns 0-4 left (stern) to right (bow), rows 0 port, 1 middle, 2 starboard.
const CAMS := [
	["BRIDGE AFT", "bridge_aft", "1", 0, 0], ["PORT AFT", "port_aft", "2", 1, 0], ["PORT", "port", "3", 2, 0], ["PORT FWD", "port_fwd", "4", 3, 0], ["BRIDGE", "bridge", "5", 4, 0],
	["STERN", "stern", "6", 0, 1], ["BOW", "bow", "7", 4, 1],
	["KEEL", "keel", "8", 0, 2], ["STBD AFT", "stbd_aft", "9", 1, 2], ["STARBOARD", "stbd", "0", 2, 2], ["STBD FWD", "stbd_fwd", "-", 3, 2], ["SEA FLOOR", "floor", "=", 4, 2],
]
const KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_EQUAL]
const SMALL := Vector2i(224, 128)
const BIG := Vector2i(768, 432)
const NEAR := 6.0 ## m: further than this the screens go dark and stop rendering
const CELL := Vector2(0.46, 0.28) ## a small screen's spot on the panel
const GRID_Y := 1.42 ## the middle row's height
const PANEL_Z := -0.82
const SCREEN := Vector2(0.42, 0.236)
const BIG_SIZE := Vector2(1.1, 0.62)
const BIG_AT := Vector3(0, 2.1, -0.82)
const OUTLINE := Vector2(1.3, 0.2) ## the drawing of her in the middle row

var big := 6 ## which camera is on the big screen (the bow)
var _views: Array[SubViewport] = []
var _cams: Array[Camera3D] = []
var _envs: Array[Environment] = []
var _skies: Array[ToonSky] = []
var _big_view: SubViewport
var _big_cam: Camera3D
var _big_env: Environment
var _big_sky: ToonSky
var _screens: Array[MeshInstance3D] = []
var _frames: Array[MeshInstance3D] = []
var _big_screen: MeshInstance3D
var _big_label: Label3D
var _big_dot: MeshInstance3D
var _dots: Array[MeshInstance3D] = []
var _dims := {}
var _live := false
var _frame := 0


## Where screen `i` sits on the panel (station space).
static func cell_at(i: int) -> Vector3:
	var c: Array = CAMS[i]
	return Vector3((int(c[3]) - 2) * CELL.x, GRID_Y + (1 - int(c[4])) * CELL.y, PANEL_Z)


func _ready() -> void:
	var grey := Color("#4A524C")
	Build.box(self, Vector3(1.8, 0.85, 0.5), Vector3(0, 0.425, -0.6), grey)
	Build.box(self, Vector3(2.45, 1.7, 0.06), Vector3(0, 1.7, -0.86), Color("#2A2E2B"), false) # the panel the screens sit in
	_dims = ShipModels.own_dims(Game.instance.sub_class) if Game.instance != null and Game.instance.sub_class != null else {}
	for i in CAMS.size():
		var at := cell_at(i)
		_screens.append(_screen(SCREEN, at))
		_frames.append(_screens[i].get_meta("bezel"))
		var l := Build.label(self, "%s %s" % [CAMS[i][2], CAMS[i][0]], at + Vector3(-SCREEN.x * 0.5 + 0.015, -SCREEN.y * 0.5 + 0.02, 0.012), 13, UiKit.CREAM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.outline_size = 6
		l.pixel_size = 0.0016
	# The drawing of her in the middle row, a dot where each camera sits, a thin line to its screen.
	var mid := Vector3(0, GRID_Y, PANEL_Z + 0.006)
	_outline(self, mid, OUTLINE, Color("#6FA88A"))
	Build.label(self, "STERN", mid + Vector3(-OUTLINE.x * 0.5 + 0.08, 0.13, 0.004), 12, UiKit.DIM).pixel_size = 0.0015
	Build.label(self, "BOW ▶", mid + Vector3(OUTLINE.x * 0.5 - 0.1, 0.13, 0.004), 12, UiKit.DIM).pixel_size = 0.0015
	for i in CAMS.size():
		var dot := _dot(self, mid + _on_outline(i, OUTLINE), 0.014, UiKit.CREAM)
		_dots.append(dot)
		var to := cell_at(i) + Vector3(0, (0.0 if int(CAMS[i][4]) == 1 else (-SCREEN.y * 0.5 if int(CAMS[i][4]) == 0 else SCREEN.y * 0.5)), 0.004)
		if int(CAMS[i][4]) == 1:
			to.x += -SCREEN.x * 0.5 if int(CAMS[i][3]) == 4 else SCREEN.x * 0.5
		_line(dot.position, to)
	_big_screen = _screen(BIG_SIZE, BIG_AT)
	_big_label = Build.label(self, "", BIG_AT + Vector3(0, BIG_SIZE.y * 0.5 + 0.06, 0.01), 20, UiKit.BRASS)
	# On the big screen, bottom right: her outline with a red dot where the camera on it is.
	var corner := BIG_AT + Vector3(BIG_SIZE.x * 0.5 - 0.2, -BIG_SIZE.y * 0.5 + 0.06, 0.008)
	Build.box(self, Vector3(0.38, 0.1, 0.004), corner + Vector3(0, 0, -0.003), Color("#0D1210"), false)
	_outline(self, corner, Vector2(0.34, 0.06), Color("#8FD1AE"))
	_big_dot = _dot(self, corner, 0.012, Color("#FF3A2A"))
	_big_dot.set_meta("corner", corner)
	Build.label(self, "OUTSIDE CAMERAS", Vector3(0, 0.95, -0.34), 20, UiKit.BRASS).rotation.x = -0.6
	Build.label(self, "click a screen", Vector3(0, 0.88, -0.27), 13, UiKit.DIM).rotation.x = -0.6
	Build.hitbox(self, Vector3(1.8, 1.0, 0.5), Vector3(0, 0.5, -0.6))
	set_view(Vector3(0, 1.62, 0.78), Vector3(0, 1.66, -0.86))
	bot_arms = Vector2(0.12, 0.6) # watching the screens, a hand on the console
	var world: World3D = Game.instance.exterior.viewport.find_world_3d()
	for i in CAMS.size():
		var v := _viewport(SMALL, world)
		_views.append(v)
		_cams.append(v.get_child(0))
		var env := Game.instance.exterior.environment().duplicate() as Environment
		var sky := ToonSky.new()
		var s := Sky.new()
		s.sky_material = sky
		env.sky = s
		_envs.append(env)
		_skies.append(sky)
	_big_view = _viewport(BIG, world)
	_big_cam = _big_view.get_child(0)
	_big_env = Game.instance.exterior.environment().duplicate() as Environment
	_big_sky = ToonSky.new()
	var bs := Sky.new()
	bs.sky_material = _big_sky
	_big_env.sky = bs
	_show_big()


## Her outline seen from above, bow to the right: a flat cigar of `size` with the fin in the middle.
static func _outline(parent: Node3D, at: Vector3, size: Vector2, c: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINE_STRIP)
	var n := 40
	for k in n + 1:
		var a := TAU * k / n
		var x := cos(a)
		var w := sin(a) * (pow(1.0 - pow(absf(x), 4.0), 0.5) if x > 0.0 else pow(1.0 - pow(absf(x), 2.2), 0.6)) # round bow, tapering stern
		st.add_vertex(Vector3(x * size.x * 0.5, w * size.y * 0.5, 0))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.position = at
	mi.material_override = _glow_mat(c)
	parent.add_child(mi)
	var fin := SurfaceTool.new() # the fin, a short rounded box amidships
	fin.begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p: Vector2 in [Vector2(-0.07, -0.2), Vector2(0.06, -0.2), Vector2(0.08, 0.0), Vector2(0.06, 0.2), Vector2(-0.07, 0.2), Vector2(-0.07, -0.2)]:
		fin.add_vertex(Vector3(p.x * size.x, p.y * size.y, 0))
	var fm := MeshInstance3D.new()
	fm.mesh = fin.commit()
	fm.position = at
	fm.material_override = mi.material_override
	parent.add_child(fm)


static func _glow_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


static func _dot(parent: Node3D, at: Vector3, r: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 8
	s.rings = 4
	mi.mesh = s
	mi.material_override = _glow_mat(c)
	mi.position = at
	parent.add_child(mi)
	return mi


func _line(a: Vector3, b: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.add_vertex(a)
	st.add_vertex(b)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _glow_mat(Color("#3D5A4A"))
	add_child(mi)


## Where camera `i` sits on an outline `size` across, from its middle: along her (stern left,
## bow right) and across her (port up, starboard down), from the camera's own mount.
func _on_outline(i: int, size: Vector2) -> Vector3:
	if _dims.is_empty():
		return Vector3.ZERO
	var m := _mount(CAMS[i][1], _dims).origin
	var along := clampf(-m.z / float(_dims.length), -0.5, 0.5)
	var across := clampf(-m.x / (float(_dims.beam) * 0.5), -1.0, 1.0)
	return Vector3(along * size.x * 0.96, across * size.y * 0.45, 0.004)


func _screen(size: Vector2, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.position = at
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.05, 0.08, 0.07)
	mi.material_override = m
	add_child(mi)
	mi.set_meta("bezel", Build.box(self, Vector3(size.x + 0.03, size.y + 0.03, 0.03), at + Vector3(0, 0, -0.02), Color("#1A1C1A"), false))
	return mi


func _viewport(size: Vector2i, world: World3D) -> SubViewport:
	var v := SubViewport.new()
	v.size = size
	v.world_3d = world
	v.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var c := Camera3D.new()
	c.near = 0.2
	c.far = 4000.0
	c.fov = 70.0
	c.current = true
	c.cull_mask = 0xFFFFF # sees our own boat (render layer 2) too
	v.add_child(c)
	add_child(v)
	return v


## Where camera `kind` sits on our boat and which way it looks, in the boat's own space
## (z bow (-) to stern (+), x starboard, y up from the waterline).
func _mount(kind: String, d: Dictionary) -> Transform3D:
	var l: float = d.length
	var deck: float = d.deck
	var side := func(z: float) -> float: # just off her side, at z
		return OwnBoat.half_at(d, OwnBoat.t_of(d, z), deck * 0.3) + 0.5
	var top := deck + float(d.ct_h) + 2.0
	match kind:
		"bow":
			return _looking(Vector3(0, deck + 1.2, -l * 0.5 + 7.0), Vector3(0, deck - 1.0, -l * 0.5 - 30.0))
		"stern":
			return _looking(Vector3(0, deck + 1.2, l * 0.5 - 6.0), Vector3(0, deck - 1.0, l * 0.5 + 30.0))
		"port", "stbd":
			var s := -1.0 if kind == "port" else 1.0
			return _looking(Vector3(s * side.call(float(d.ct_z)), deck * 0.5, float(d.ct_z)), Vector3(s * 60.0, deck - 8.0, float(d.ct_z) - 6.0))
		"port_fwd", "stbd_fwd":
			var s := -1.0 if kind == "port_fwd" else 1.0
			var z := -l * 0.3
			return _looking(Vector3(s * side.call(z), deck * 0.5, z), Vector3(s * 45.0, deck - 8.0, z - 35.0))
		"port_aft", "stbd_aft":
			var s := -1.0 if kind == "port_aft" else 1.0
			var z := l * 0.28
			return _looking(Vector3(s * side.call(z), deck * 0.5, z), Vector3(s * 45.0, deck - 8.0, z + 35.0))
		"bridge":
			return _looking(Vector3(0, top, float(d.ct_z) + float(d.ct_len) * 0.5), Vector3(0, deck, -l * 0.5 - 20.0))
		"bridge_aft":
			return _looking(Vector3(0, top, float(d.ct_z) - float(d.ct_len) * 0.5), Vector3(0, deck, l * 0.5 + 20.0))
		"floor": # under her forefoot, straight down at the sea floor, by the keel floodlight
			return Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), Vector3(0, -float(d.draft) - 1.0, -l * 0.25))
		_: # keel: under the hull, looking ahead and down
			return _looking(Vector3(0, -float(d.draft) - 1.0, l * 0.1), Vector3(0, -float(d.draft) - 10.0, -l * 0.2 - 30.0))


static func _looking(from: Vector3, to: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(to - from, Vector3.UP), from)


func _process(_delta: float) -> void:
	var me := Game.instance.local_player
	var live := me != null and Sim.world != null and me.global_position.distance_to(global_position) < NEAR \
			and not Game.instance.menu_open()
	if live != _live:
		_live = live
		for i in _screens.size():
			(_screens[i].material_override as StandardMaterial3D).albedo_color = Color.WHITE if live else Color(0.05, 0.08, 0.07)
			(_screens[i].material_override as StandardMaterial3D).albedo_texture = _views[i].get_texture() if live else null
		(_big_screen.material_override as StandardMaterial3D).albedo_color = Color.WHITE if live else Color(0.05, 0.08, 0.07)
		(_big_screen.material_override as StandardMaterial3D).albedo_texture = _big_view.get_texture() if live else null
		if not live:
			for v in _views:
				v.render_target_update_mode = SubViewport.UPDATE_DISABLED
			_big_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if not live:
		return
	var own := Game.instance.exterior.own_boat()
	if own == null:
		return
	var d := ShipModels.own_dims(Sim.world.sub.data)
	if _dims.is_empty():
		_dims = d
		_show_big()
	_frame += 1
	# Small screens take turns (one a frame), the big one every frame.
	var turn := _frame % _views.size()
	_aim(_cams[turn], _envs[turn], _skies[turn], own.global_transform * _mount(CAMS[turn][1], d))
	_views[turn].render_target_update_mode = SubViewport.UPDATE_ONCE
	_aim(_big_cam, _big_env, _big_sky, own.global_transform * _mount(CAMS[big][1], d))
	_big_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS


## The big screen's title, its red dot on the outline, and the chosen screen's dot and frame lit.
func _show_big() -> void:
	_big_label.text = "%s  %s" % [CAMS[big][2], CAMS[big][0]]
	_big_dot.position = (_big_dot.get_meta("corner") as Vector3) + _on_outline(big, Vector2(0.34, 0.06)) + Vector3(0, 0, 0.004)
	for i in _dots.size():
		(_dots[i].material_override as StandardMaterial3D).albedo_color = Color("#FF3A2A") if i == big else UiKit.CREAM
		_dots[i].scale = Vector3.ONE * (1.6 if i == big else 1.0)
		_frames[i].material_override = _glow_mat(Color("#C9A04A")) if i == big else null


func _aim(cam: Camera3D, env: Environment, sky: ToonSky, t: Transform3D) -> void:
	cam.global_transform = t
	var depth := -t.origin.y
	if depth > 0.0:
		ExteriorWorld.paint_water(env, sky, depth, Sim.world.conditions.night)
		cam.environment = env
		cam.far = ExteriorWorld.see_under(depth)
	else:
		cam.environment = null
		cam.far = 4000.0


func choose(i: int) -> void:
	if i < 0 or i >= CAMS.size() or i == big:
		return
	big = i
	_show_big()
	Sfx.play_at(self, "click", Vector3(0, 1.0, -0.5), -6.0)


## The screen a ray from `from` along `dir` hits on the panel, or -1.
func screen_at(from: Vector3, dir: Vector3) -> int:
	var inv := global_transform.affine_inverse()
	var o := inv * from
	var v := inv.basis * dir
	if absf(v.z) < 1e-5:
		return -1
	var t := (PANEL_Z - o.z) / v.z
	if t <= 0.0:
		return -1
	var hit := o + v * t
	for i in CAMS.size():
		var c := cell_at(i)
		if absf(hit.x - c.x) <= SCREEN.x * 0.5 and absf(hit.y - c.y) <= SCREEN.y * 0.5:
			return i
	return -1


func on_enter() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func on_leave() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	super.on_leave()


func station_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		choose(KEYS.find(event.physical_keycode))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			var mp := get_viewport().get_mouse_position()
			choose(screen_at(cam.project_ray_origin(mp), cam.project_ray_normal(mp)))


func _build_overlay(root: Control) -> void:
	var box := UiKit.bottom_panel(root)
	box.add_child(UiKit.label("OUTSIDE CAMERAS — click a screen (or its key, 1-9 0 - =) to put it on the big screen; the red dot shows where on her it is", 17))
	box.add_child(UiKit.label("Laid out like the boat from above: bow to the right, port along the top, starboard along the bottom   [Q] leave the console", 15, UiKit.DIM))
	for c in box.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
