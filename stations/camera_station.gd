class_name CameraStation
extends Station
## The camera bank in the navigation room (Blaney: "cameras around the outside of the sub,
## there should be a viewing center"; both a wall of small screens and one big one). Six
## cameras on our own boat in the ocean outside: bow, stern, port, starboard, the bridge and
## under the keel. The small screens all run while someone is in the room; man the console
## and 1-6 puts one on the big screen. They render only while the local player is near.

const CAMS := [
	["BOW", "bow"], ["STERN", "stern"], ["PORT", "port"], ["STARBOARD", "stbd"], ["BRIDGE", "bridge"], ["KEEL", "keel"],
]
const SMALL := Vector2i(256, 144)
const BIG := Vector2i(768, 432)
const NEAR := 6.0 ## m: further than this the screens go dark and stop rendering

var big := 0 ## which camera is on the big screen
var _views: Array[SubViewport] = []
var _cams: Array[Camera3D] = []
var _envs: Array[Environment] = []
var _skies: Array[ToonSky] = []
var _big_view: SubViewport
var _big_cam: Camera3D
var _big_env: Environment
var _big_sky: ToonSky
var _screens: Array[MeshInstance3D] = []
var _big_screen: MeshInstance3D
var _big_label: Label3D
var _live := false
var _frame := 0


func _ready() -> void:
	# A grey console under a bank of six screens (3 x 2) and a big one above them.
	var grey := Color("#4A524C")
	Build.box(self, Vector3(1.8, 0.85, 0.5), Vector3(0, 0.425, -0.6), grey)
	Build.box(self, Vector3(2.0, 1.55, 0.06), Vector3(0, 1.75, -0.86), Color("#2A2E2B"), false) # the panel the screens sit in
	for i in CAMS.size():
		var at := Vector3(-0.6 + (i % 3) * 0.6, 1.33 - (i / 3) * 0.33, -0.82)
		_screens.append(_screen(Vector2(0.5, 0.28), at))
		var l := Build.label(self, "%d %s" % [i + 1, CAMS[i][0]], at + Vector3(-0.22, -0.12, 0.012), 14, UiKit.CREAM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.pixel_size = 0.0018
	_big_screen = _screen(Vector2(1.2, 0.675), Vector3(0, 2.02, -0.82))
	_big_label = Build.label(self, "", Vector3(0, 2.42, -0.81), 22, UiKit.BRASS)
	Build.label(self, "OUTSIDE CAMERAS", Vector3(0, 0.95, -0.34), 20, UiKit.BRASS).rotation.x = -0.6
	Build.hitbox(self, Vector3(1.8, 1.0, 0.5), Vector3(0, 0.5, -0.6))
	set_view(Vector3(0, 1.62, 0.5), Vector3(0, 1.75, -0.86))
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
		(_screens[i].material_override as StandardMaterial3D).albedo_texture = v.get_texture()
	_big_view = _viewport(BIG, world)
	_big_cam = _big_view.get_child(0)
	_big_env = Game.instance.exterior.environment().duplicate() as Environment
	_big_sky = ToonSky.new()
	var bs := Sky.new()
	bs.sky_material = _big_sky
	_big_env.sky = bs
	(_big_screen.material_override as StandardMaterial3D).albedo_texture = _big_view.get_texture()


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
	Build.box(self, Vector3(size.x + 0.05, size.y + 0.05, 0.03), at + Vector3(0, 0, -0.02), Color("#1A1C1A"), false) # bezel
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


## Where camera `kind` sits on our boat and which way it looks, in the boat's own space.
func _mount(kind: String, d: Dictionary) -> Transform3D:
	var l: float = d.length
	var deck: float = d.deck
	var fw := float(d.beam) * 0.16 + 0.15
	match kind:
		"bow":
			return _looking(Vector3(0, deck + 1.2, -l * 0.5 + 7.0), Vector3(0, deck - 1.0, -l * 0.5 - 30.0))
		"stern":
			return _looking(Vector3(0, deck + 1.2, l * 0.5 - 6.0), Vector3(0, deck - 1.0, l * 0.5 + 30.0))
		"port":
			return _looking(Vector3(-fw, deck + 2.5, d.ct_z), Vector3(-60.0, deck - 4.0, d.ct_z - 10.0))
		"stbd":
			return _looking(Vector3(fw, deck + 2.5, d.ct_z), Vector3(60.0, deck - 4.0, d.ct_z - 10.0))
		"bridge":
			return _looking(Vector3(0, deck + float(d.ct_h) + 2.0, float(d.ct_z) + float(d.ct_len) * 0.5), Vector3(0, deck, -l * 0.5 - 20.0))
		_: # keel: under the hull, looking ahead and down
			return _looking(Vector3(0, -5.2, -l * 0.2), Vector3(0, -14.0, -l * 0.2 - 30.0))


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
	var ext := Game.instance.exterior
	var own := ext.own_boat()
	if own == null:
		return
	var d := ShipModels.own_dims(Sim.world.sub.data)
	_frame += 1
	# Small screens take turns (one a frame), the big one every frame.
	var turn := _frame % _views.size()
	for i in _views.size():
		if i == turn:
			_aim(_cams[i], _envs[i], _skies[i], own.global_transform * _mount(CAMS[i][1], d))
			_views[i].render_target_update_mode = SubViewport.UPDATE_ONCE
	_aim(_big_cam, _big_env, _big_sky, own.global_transform * _mount(CAMS[big][1], d))
	_big_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_big_label.text = "%d  %s" % [big + 1, CAMS[big][0]]


func _aim(cam: Camera3D, env: Environment, sky: ToonSky, t: Transform3D) -> void:
	cam.global_transform = t
	var depth := -t.origin.y
	if depth > 0.0:
		ExteriorWorld.paint_water(env, sky, depth, Sim.world.conditions.night)
		cam.environment = env
	else:
		cam.environment = null


func station_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var n: int = event.physical_keycode - KEY_1
		if n >= 0 and n < CAMS.size():
			big = n
			Sfx.play_at(self, "click", Vector3(0, 1.0, -0.5), -6.0)


func _build_overlay(root: Control) -> void:
	var box := UiKit.bottom_panel(root)
	box.add_child(UiKit.label("OUTSIDE CAMERAS — [1] Bow  [2] Stern  [3] Port  [4] Starboard  [5] Bridge  [6] Keel  on the big screen", 18))
	box.add_child(UiKit.label("[Q] leave the console", 16, UiKit.DIM))
