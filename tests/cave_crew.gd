extends SceneTree
## The crew take her through the cave on their own (Blaney: "i do want to be on board when the
## crew does it"): "take us through the cave" on the PA (or "all hands on deck"), and they must
## come out of the far end, with few scrapes.
##   godot --headless --path . -s tests/cave_crew.gd -- <sub> [pa | all_hands]

var _game: Node
var _t := 0.0
var _how := "pa"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var net: Node = root.get_node("Net")
	net.sub_key = args[0] if not args.is_empty() else "gato"
	_how = args[1] if args.size() > 1 else "pa"
	net.mission = "cw_cave" if net.sub_key == "typhoon" else ("titan_cave" if net.sub_key == "titan" else "cave")
	net.mode = 1
	net.port = int(OS.get_environment("TEST_PORT")) if OS.has_environment("TEST_PORT") else 7100 + OS.get_process_id() % 2000 # tests/walkthroughs.sh gives each its own
	Engine.time_scale = 4.0
	change_scene_to_file.call_deferred("res://game/game.tscn")


func _physics_process(delta: float) -> bool:
	if _game == null:
		if current_scene != null and current_scene.name == "Game":
			_game = current_scene
		return false
	var w: Variant = root.get_node("Sim").get("world")
	if w == null or _game.local_player == null:
		return false
	var before := _t
	_t += delta
	if before < 3.0 and _t >= 3.0:
		_game.rq_pa("take us through the cave" if _how == "pa" else "all hands on deck")
	if int(_t) != int(before) and int(_t) % 10 == 0:
		print("cave_crew: %3d s depth %.1f ordered %.1f heading %.0f speed %.1f scrapes %d through %d" % [int(_t), w.sub.depth, w.sub.ordered_depth, w.sub.heading, w.sub.speed, w.cave_scrapes, w.caves_through])
	if not w.event.is_connected(_on_event):
		w.event.connect(_on_event)
	if w.caves_through >= 1:
		print("%s: through in %d s, %d scrapes (%s, %s)" % ["ok" if w.cave_scrapes <= 3 else "FAIL", int(_t), w.cave_scrapes, _how, root.get_node("Net").sub_key])
		quit(0 if w.cave_scrapes <= 3 else 1)
		return true
	if _t > 900.0:
		print("FAIL: not through after %d s (%d scrapes)" % [int(_t), w.cave_scrapes])
		quit(1)
		return true
	return false


func _on_event(kind: String, d: Dictionary) -> void:
	if kind == "grounded":
		var w: Variant = root.get_node("Sim").get("world")
		print("cave_crew: %s at depth %.1f heading %.0f" % [d.text, w.sub.depth, w.sub.heading])
