extends SceneTree
## A ship model on a flat sea, three-quarter view, for checking how it looks:
##   godot --path . --rendering-driver opengl3 -s tools/ship_gallery.gd -- <class | plane>
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
