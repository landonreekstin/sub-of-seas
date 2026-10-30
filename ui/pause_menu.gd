class_name PauseMenu
extends CanvasLayer
## Esc on a patrol: resume, settings, leave to the main menu. The boat keeps going while it
## is open when others are aboard; it only truly pauses for a host on their own.

var is_open := false
var _root: Control
var _mouse_before := Input.MOUSE_MODE_CAPTURED
var _settings: SettingsMenu
var _panel: Control ## the pause panel, hidden while settings is over it


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UiKit.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var p := UiKit.panel()
	center.add_child(p)
	_panel = p
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size.x = 320
	p.add_child(box)
	box.add_child(UiKit.label("PAUSED", 30, UiKit.BRASS))
	var note := UiKit.label("", 15, UiKit.DIM)
	note.name = "Note"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	for item: Array in [["Resume", close], ["Settings", _open_settings], ["Leave to the main menu", _leave]]:
		var b := Button.new()
		b.text = item[0]
		b.name = item[0]
		b.pressed.connect(item[1])
		box.add_child(b)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _settings != null:
		return # it closes itself on Esc
	get_viewport().set_input_as_handled()
	if is_open:
		close()
	else:
		open()


func open() -> void:
	is_open = true
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var alone := multiplayer.is_server() and multiplayer.get_peers().is_empty()
	(_root.find_child("Note", true, false) as Label).text = "Game paused." if alone else "The boat carries on while you're in here: your crewmates are still aboard."
	get_tree().paused = alone
	_root.visible = true
	(_root.find_child("Resume", true, false) as Button).grab_focus()


func close() -> void:
	if _settings != null:
		_settings.close()
	is_open = false
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = _mouse_before


func _open_settings() -> void:
	_settings = SettingsMenu.new()
	_root.add_child(_settings)
	_panel.visible = false
	_settings.closed.connect(func() -> void:
		_settings = null
		_panel.visible = true
		(_root.find_child("Settings", true, false) as Button).grab_focus())


func _leave() -> void:
	close()
	Game.instance.leave()
