extends Control
## Title screen: name, host, or join a LAN game by IP.

const GAME_SCENE := "res://game/game.tscn"

var _name_edit: LineEdit
var _ip_edit: LineEdit


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

	var host := Button.new()
	host.text = "Host a patrol"
	host.pressed.connect(_host)
	box.add_child(host)

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
	box.add_child(UiKit.label("Host needs UDP port %d open on the LAN." % Net.port, 14, UiKit.DIM))

	match Net.cli_start:
		Net.Mode.HOST:
			_host.call_deferred()
		Net.Mode.CLIENT:
			_join.call_deferred()
	Net.cli_start = Net.Mode.NONE


func _host() -> void:
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
