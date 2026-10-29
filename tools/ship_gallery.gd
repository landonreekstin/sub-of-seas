extends SceneTree
## A ship model on a flat sea, three-quarter view, for checking how it looks:
##   godot --path . --rendering-driver opengl3 -s tools/ship_gallery.gd -- <class>
## (under xvfb-run, add a screenshot). Bow points right.

const CLASSES := ["subchaser", "kaibokan", "destroyer", "freighter", "tanker", "cruiser", "battleship", "carrier"]


func _initialize() -> void:
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
	cam.position = Vector3(-d.length * 0.25, d.length * 0.35, d.length * 1.3)
	cam.look_at(Vector3(0, d.length * 0.05, 0))
