extends SceneTree
## A cave for a boat, on its own, for checking how it looks:
##   godot --path . --rendering-driver opengl3 -s tools/cave_look.gd -- <sub> <out.png> <air | mouth | inside | over>
## (under xvfb-run). The tunnel runs north (away from the camera at "mouth").


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var args := OS.get_cmdline_user_args()
	var data: SubClassData = load("res://data/subs/%s.tres" % (args[0] if args.size() > 0 else "gato"))
	var view: String = args[2] if args.size() > 2 else "mouth"
	var root3d := Node3D.new()
	root.add_child(root3d)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0E3A4F") if view != "air" else Color("#BFD8E8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8FA8BF")
	env.ambient_light_energy = 0.5
	env.glow_enabled = true
	if view != "air":
		env.fog_enabled = true
		env.fog_light_color = Color("#0E3A4F")
		env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	root3d.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	root3d.add_child(sun)
	var s := Seabed.new()
	var f := s.add_cave(Vector2(0, 0), PI * 0.5, Seabed.cave_size(data.length, data.beam, data.height, data.test_depth))
	var rng := RandomNumberGenerator.new()
	root3d.add_child(CaveView.build(f, rng))
	var mid := (Seabed.cave_roof(f, -350.0) + Seabed.cave_bottom(f, -350.0)) * 0.5
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 20000.0
	root3d.add_child(cam)
	match view:
		"air":
			cam.look_at_from_position(Vector3(-900, 500, 1400), Vector3(0, 0, 0))
		"over":
			cam.look_at_from_position(Vector3(0, 1400, 10), Vector3(0, 0, 0))
		"inside":
			var p := Seabed.cave_world(f, Vector2(-150.0, Seabed.cave_centre(f, -150.0)))
			var q := Seabed.cave_world(f, Vector2(-80.0, Seabed.cave_centre(f, -80.0)))
			var m2 := (Seabed.cave_roof(f, -150.0) + Seabed.cave_bottom(f, -150.0)) * 0.5
			cam.look_at_from_position(Vector3(p.x, -m2, -p.y), Vector3(q.x, -m2, -q.y))
		_:
			cam.look_at_from_position(Vector3(0, -mid + 5, 350 + 160), Vector3(0, -mid, 0))
	var light := OmniLight3D.new() # the boat's own lamp
	light.omni_range = 120.0
	light.light_energy = 2.0
	cam.add_child(light)
	await create_timer(2.0).timeout
	root.get_texture().get_image().save_png(args[1] if args.size() > 1 else "cave.png")
	quit()
