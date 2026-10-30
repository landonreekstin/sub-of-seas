class_name MainMenu
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
	Music.play("menu")
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
	box.add_theme_constant_override("separation", 7)
	box.custom_minimum_size.x = 420
	p.add_child(box)

	box.add_child(UiKit.label("SUB OF SEAS", 44, UiKit.BRASS))
	box.add_child(UiKit.label("Pacific patrol, 1943", 18, UiKit.DIM))
	_name_edit = LineEdit.new()
	_name_edit.text = Net.player_name
	_name_edit.placeholder_text = "Your name"
	box.add_child(_name_edit)

	_sailor_row(box)
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
	_briefing.custom_minimum_size = Vector2(420, 70)
	box.add_child(_briefing)
	_show_briefing()
	_sub = OptionButton.new()
	for k in SUBS:
		var d: SubClassData = load("res://data/subs/%s.tres" % k)
		_sub.add_item("%s   (crew %d–%d)" % [d.display_name, d.crew_min, d.crew_max])
	_sub.select(maxi(SUBS.find(Net.sub_key), 0))
	box.add_child(_sub)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var host := Button.new()
	host.text = "Host this patrol"
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.pressed.connect(_host)
	buttons.add_child(host)
	var training := Button.new()
	training.text = "Training patrol"
	training.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	training.pressed.connect(_show_courses)
	buttons.add_child(training)

	box.add_child(UiKit.label("Join a crew at", 16))
	var join_row := HBoxContainer.new()
	box.add_child(join_row)
	_ip_edit = LineEdit.new()
	_ip_edit.text = Net.address
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_ip_edit)
	var join := Button.new()
	join.text = "  Join  "
	join.pressed.connect(_join)
	join_row.add_child(join)

	var settings := Button.new()
	settings.text = "Settings"
	settings.pressed.connect(func() -> void: add_child(SettingsMenu.new()))
	box.add_child(settings)

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


## Rank, career, and the sailor you take aboard (the editor makes them).
func _sailor_row(box: VBoxContainer) -> void:
	var p := Net.profile
	var row := HBoxContainer.new()
	box.add_child(row)
	var career := UiKit.label("%s — %d t sunk, %d patrols" % [Profile.RANKS[p.rank()][0], p.tons, p.patrols], 15, UiKit.BRASS)
	career.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(career)
	var edit := Button.new()
	edit.text = "Your sailor..."
	edit.pressed.connect(func() -> void: add_child(SailorEditor.new()))
	row.add_child(edit)


static func swatch(c: Color) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	img.fill(c)
	return ImageTexture.create_from_image(img)


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


## Training: pick the job to learn (a short course each), or the whole boat.
func _show_courses() -> void:
	var cover := Control.new()
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	var dim := ColorRect.new()
	dim.color = Color("#0B1C2E")
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.add_child(center)
	var p := UiKit.panel()
	center.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.custom_minimum_size.x = 520
	p.add_child(box)
	box.add_child(UiKit.label("TRAINING", 32, UiKit.BRASS))
	box.add_child(UiKit.label("Pick the job you want to learn. The rest of the crew is played for you.", 15, UiKit.DIM))
	for key: String in Tutorial.COURSES:
		var b := Button.new()
		b.text = Tutorial.COURSES[key]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func() -> void:
			Net.course = key
			_training())
		box.add_child(b)
		var blurb := UiKit.label(Tutorial.BLURBS[key], 14, UiKit.DIM)
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(blurb)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(cover.queue_free)
	box.add_child(back)


func _join() -> void:
	_start(Net.Mode.CLIENT)


func _start(mode: Net.Mode) -> void:
	if _name_edit.text.strip_edges() != "":
		Net.player_name = _name_edit.text.strip_edges()
	if mode == Net.Mode.CLIENT:
		Net.address = _ip_edit.text.strip_edges()
	Net.mode = mode
	get_tree().change_scene_to_file(GAME_SCENE)
