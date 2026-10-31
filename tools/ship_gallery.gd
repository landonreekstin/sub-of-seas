extends SceneTree
## A ship model on a flat sea, three-quarter view, for checking how it looks:
##   godot --path . --rendering-driver opengl3 -s tools/ship_gallery.gd -- <class | plane | crew | sealife | own[_<sub>]> [out.png] [eye]
## (under xvfb-run, add a screenshot). Bow points right.

const CLASSES := ["subchaser", "kaibokan", "destroyer", "freighter", "tanker", "cruiser", "battleship", "carrier"]


func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_position(Vector2i.ZERO)
	var root3d := Node3D.new()
	root.add_child(root3d)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#BFD8E8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8FA8BF")
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	root3d.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -40, 0)
	root3d.add_child(sun)
	Build.box(root3d, Vector3(3000, 0.1, 400), Vector3(600, -0.05, 0), Color("#1F4E79"), false)
	var args := OS.get_cmdline_user_args()
	var k: String = args[0] if not args.is_empty() else "destroyer"
	if k == "crew": # a line of sailors with different looks, faces close up
		for i in 4:
			var m := Node3D.new()
			m.position = Vector3((i - 1.5) * 0.9, 0, 0)
			m.rotation.y = (i - 1.5) * -0.2
			root3d.add_child(m)
			var look := {"skin": i, "hair": [0, 3, 6, 2][i], "hair_col": i + 1, "beard": [0, 2, 5, 1][i], "extra": [0, 2, 4, 1][i], "build": i}
			Crewman.build_body(m, look, Color.from_hsv(0.15 * i + 0.5, 0.45, 0.85))
			var face := Node3D.new()
			face.position.y = 1.6 # Player.EYE_HEIGHT (Player needs the autoloads)
			m.add_child(face)
			Crewman.build_face(face, look)
		var cc := Camera3D.new()
		cc.fov = 35.0
		root3d.add_child(cc)
		cc.look_at_from_position(Vector3(0.2, 1.55, -2.6), Vector3(0, 1.4, 0))
		env.background_color = Color("#14324F")
		if args.size() > 1:
			_save(args[1])
		return
	if k == "sealife": # a humpback, a shark and a few fish, side by side
		var w := Creatures.whale()
		w.rotation.y = PI * 0.5
		w.position = Vector3(0, 4, 0)
		root3d.add_child(w)
		var sh := Creatures.shark()
		sh.rotation.y = PI * 0.5
		sh.position = Vector3(2, 4, 9)
		root3d.add_child(sh)
		for i in 4:
			var f := MeshInstance3D.new()
			f.mesh = Creatures.fish_mesh()
			f.material_override = Creatures.creature_mat()
			f.position = Vector3(-4 + i * 1.2, 5.5, 10)
			f.rotation.y = PI * 0.5
			root3d.add_child(f)
		var cs := Camera3D.new()
		cs.fov = 50.0
		root3d.add_child(cs)
		cs.look_at_from_position(Vector3(-4, 7, 22), Vector3(0, 4, 2))
		if args.size() > 1:
			_save(args[1])
		return
	if k.begins_with("own"): # our own boat on the surface, by the gun: own, own_s_boat, own_narwhal
		var sk := k.trim_prefix("own_") if k != "own" else "gato"
		var sd: SubClassData = load("res://data/subs/%s.tres" % sk)
		var ob := ShipModels.own_boat(sd)
		root3d.add_child(ob)
		var gun: Node3D = ob.get_node("Gun")
		gun.rotation.y = deg_to_rad(-25.0)
		var co := Camera3D.new()
		co.fov = 50.0
		root3d.add_child(co)
		if args.size() > 2 and args[2] == "eye": # what the gunlayer sees
			co.transform = gun.transform * (gun.get_node("Eye") as Node3D).transform
		else:
			co.look_at_from_position(Vector3(sd.length * 0.35, sd.length * 0.12, -sd.length * 0.25), Vector3(0, 2, -sd.length * 0.15))
		if args.size() > 1:
			_save(args[1])
		return
	if k == "plane": # the patrol plane, in the air
		var p := ShipModels.plane()
		p.position.y = 3.0
		root3d.add_child(p)
		var c := Camera3D.new()
		root3d.add_child(c)
		c.look_at_from_position(Vector3(-14, 9, 12), p.position)
		return
	var d: ShipClassData = load("res://data/ships/%s.tres" % k)
	var m := ShipModels.build(d)
	m.rotation.y = -PI / 2.0 # bow to the right
	root3d.add_child(m)
	var l := Build.label(root3d, d.display_name, Vector3(0, d.length * 0.32, 0), 300, Color.BLACK)
	l.pixel_size = d.length / 30000.0
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.far = 10000.0
	root3d.add_child(cam)
	cam.look_at_from_position(Vector3(d.length * 0.62, d.length * 0.14, d.length * 0.3), Vector3(d.length * 0.12, d.length * 0.05, 0))
	if args.size() > 1: # an output path: save a screenshot there and quit
		_save(args[1])


func _save(path: String) -> void:
	await create_timer(2.0).timeout
	root.get_texture().get_image().save_png(path)
	quit()
