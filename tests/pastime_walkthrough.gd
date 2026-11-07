extends SceneTree
## Bots play every pastime aboard a boat (arm wrestling each other, blackjack, the galley) and
## the T card lists them all with their rooms.
##   godot --headless --path . -s tests/pastime_walkthrough.gd -- <sub>

var _game: Node
var _t := 0.0
var _posted := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var net: Node = root.get_node("Net")
	net.sub_key = args[0] if not args.is_empty() else "gato"
	net.mission = "cw_convoy" if net.sub_key == "typhoon" else "convoy"
	net.mode = 1
	net.port = 7100 + OS.get_process_id() % 2000 # its own port, so tests can run side by side
	Engine.time_scale = 4.0
	change_scene_to_file.call_deferred("res://game/game.tscn")


func _process(delta: float) -> bool:
	if _game == null:
		if current_scene != null and current_scene.name == "Game":
			_game = current_scene
		return false
	if _game.interior == null or _game.local_player == null or root.get_node("Sim").get("world") == null:
		return false
	if not _posted:
		_posted = true
		for sid: String in Pastimes.STATIONS:
			if _game.interior.stations.has(sid):
				_game.bot_crew.request(sid, "post", null)
		return false
	_t += delta
	if _t < 45.0:
		return false
	var crew: Dictionary = _game.crew
	var bad: Array[String] = []
	if crew.get("arm_wins", {}).is_empty():
		bad.append("nobody won at arm wrestling")
	if crew.get("cards", {}).is_empty():
		bad.append("no cards dealt")
	var card: String = _game.things_to_do.text()
	for f: Node in get_nodes_in_group("fun_spots"):
		if f.call("room") == "":
			bad.append("%s is in no room" % f.get("title"))
	for title in ["ARM WRESTLING", "BLACKJACK", "COOK'S SPECIAL"] + (["FISHING"] if _game.interior.stations.has("gun") else []):
		if not card.contains(title):
			bad.append("the card doesn't list " + title)
	print(card.split("\n\nCREW RECORDS")[0].replace("\n    ", " — ").substr(0, 900))
	print("records: " + _game.things_to_do.records().replace("\n", " | "))
	print("FAIL: " + ", ".join(bad) if not bad.is_empty() else "ok: bots play every pastime, the card lists them")
	quit(1 if not bad.is_empty() else 0)
	return true
