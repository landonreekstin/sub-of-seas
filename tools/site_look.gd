extends SceneTree
## A sea-floor place (SiteView) on its own, in dim deep water, for checking how it looks:
##   godot --path . --rendering-driver opengl3 -s tools/site_look.gd -- <wreck | ruins | vents | garden | alien> <out.png> [x,y,z]
## (under xvfb-run). The camera looks at its middle from a little above, or from x,y,z.


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var args := OS.get_cmdline_user_args()
	var type: String = args[0] if args.size() > 0 else "alien"
	var root3d := Node3D.new()
	root.add_child(root3d)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#04141E")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#3A5A6F")
	env.ambient_light_energy = 0.5
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color("#04141E")
	env.fog_density = 0.006
	var we := WorldEnvironment.new()
	we.environment = env
	root3d.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -30, 0)
	sun.light_energy = 0.25
	root3d.add_child(sun)
	Build.box(root3d, Vector3(200, 1.0, 200), Vector3(0, -0.5, 0), Color("#4A4F48"), false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var f := {"kind": "site", "type": type, "name": Seabed.SITE_NAMES[type], "x": 0.0, "y": 0.0, "top": 0.0, "r": Seabed.SITE_R}
	root3d.add_child(SiteView.build(f, rng))
	var cam := Camera3D.new()
	cam.far = 1000.0
	root3d.add_child(cam)
	var eye := Vector3(70, 35, 70)
	if args.size() > 2 and args[2].count(",") == 2:
		var v := args[2].split_floats(",")
		eye = Vector3(v[0], v[1], v[2])
	cam.look_at_from_position(eye, Vector3(0, 10, 0))
	if args.size() > 1:
		for i in 40:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png(args[1])
		quit()
