extends Control
## Title screen: name, pick and host a patrol (or the training patrol), or join by IP.

const GAME_SCENE := "res://game/game.tscn"

var _name_edit: LineEdit
var _ip_edit: LineEdit
var _mission: OptionButton
var _sub: OptionButton
const SUBS: Array[String] = ["s_boat", "gato", "narwhal"]
var _briefing: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#14324F")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := UiKit.panel()
	center.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size.x = 420
	p.add_child(box)

	box.add_child(UiKit.label("SUB OF SEAS", 44, UiKit.BRASS))
	box.add_child(UiKit.label("Pacific patrol, 1943", 18, UiKit.DIM))
	box.add_child(UiKit.label("Your name"))
	_name_edit = LineEdit.new()
	_name_edit.text = Net.player_name
	box.add_child(_name_edit)

	box.add_child(UiKit.label("Patrol"))
	_mission = OptionButton.new()
	for k in MissionData.KEYS:
		var m := MissionData.load_key(k)
		_mission.add_item("%s   %s" % [m.title, "★".repeat(m.difficulty)])
	var current := MissionData.KEYS.find(Net.mission)
	_mission.select(maxi(current, 0))
	_mission.item_selected.connect(func(_i: int) -> void: _show_briefing())
	box.add_child(_mission)
	_briefing = UiKit.label("", 15, UiKit.DIM)
	_briefing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing.custom_minimum_size = Vector2(420, 90)
	box.add_child(_briefing)
	_show_briefing()
	box.add_child(UiKit.label("Boat"))
	_sub = OptionButton.new()
	for k in SUBS:
		var d: SubClassData = load("res://data/subs/%s.tres" % k)
		_sub.add_item("%s   (crew %d–%d)" % [d.display_name, d.crew_min, d.crew_max])
	_sub.select(maxi(SUBS.find(Net.sub_key), 0))
	box.add_child(_sub)
	var host := Button.new()
	host.text = "Host this patrol"
	host.pressed.connect(_host)
	box.add_child(host)

	var training := Button.new()
	training.text = "Training patrol (host)"
	training.pressed.connect(_training)
	box.add_child(training)

	box.add_child(UiKit.label("Host address"))
	_ip_edit = LineEdit.new()
	_ip_edit.text = Net.address
	box.add_child(_ip_edit)
	var join := Button.new()
	join.text = "Join"
	join.pressed.connect(_join)
	box.add_child(join)

	if Net.last_error != "":
		box.add_child(UiKit.label(Net.last_error, 16, UiKit.BAD))
		Net.last_error = ""
	box.add_child(UiKit.label("Host needs UDP port %d open. Build %s." % [Net.port, Net.build], 14, UiKit.DIM))

	match Net.cli_start:
		Net.Mode.HOST:
			(_training if Net.mission == "training" else _host).call_deferred()
		Net.Mode.CLIENT:
			_join.call_deferred()
	Net.cli_start = Net.Mode.NONE


func _show_briefing() -> void:
	var m := MissionData.load_key(MissionData.KEYS[_mission.selected])
	_briefing.text = m.briefing


func _host() -> void:
	Net.mission = MissionData.KEYS[_mission.selected] # starts on --mission's, if given
	Net.sub_key = SUBS[_sub.selected]
	_start(Net.Mode.HOST)


func _training() -> void:
	Net.mission = "training"
	_start(Net.Mode.HOST)


func _join() -> void:
	_start(Net.Mode.CLIENT)


func _start(mode: Net.Mode) -> void:
	if _name_edit.text.strip_edges() != "":
		Net.player_name = _name_edit.text.strip_edges()
	if mode == Net.Mode.CLIENT:
		Net.address = _ip_edit.text.strip_edges()
	Net.mode = mode
	get_tree().change_scene_to_file(GAME_SCENE)
