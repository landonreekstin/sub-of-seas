class_name SettingsMenu
extends Control
## Audio, graphics and controls (see autoload/settings.gd). Opened over the main menu and
## the pause menu; every change applies and saves at once. Back or Esc closes it.

signal closed

var _tabs: TabContainer
var _key_buttons := {} ## action -> Button
var _waiting := "" ## the action waiting for a key press, or ""


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := UiKit.panel()
	center.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(600, 0)
	p.add_child(box)
	box.add_child(UiKit.label("SETTINGS", 30, UiKit.BRASS))
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size.y = 400
	box.add_child(_tabs)
	_audio_tab()
	_graphics_tab()
	_controls_tab()
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(close)
	box.add_child(back)
	back.grab_focus.call_deferred()


func close() -> void:
	_waiting = ""
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _waiting != "":
		get_viewport().set_input_as_handled()
		if event.physical_keycode != KEY_ESCAPE:
			Settings.set_key(_waiting, event.physical_keycode)
		_waiting = ""
		_refresh_keys()
	elif event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	scroll.add_child(margin)
	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 8)
	margin.add_child(grid)
	return grid


func _row(page: VBoxContainer, text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var l := UiKit.label(text, 17)
	l.custom_minimum_size.x = 250
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	page.add_child(row)


## A 0–100 % slider for a 0..1 setting (or `lo`..`hi` shown as `fmt`).
func _slider(page: VBoxContainer, text: String, key: String, lo := 0.0, hi := 1.0, step := 0.01, fmt := "%d%%", scale := 100.0) -> void:
	var row := HBoxContainer.new()
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.get_value(key))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var shown := UiKit.label(fmt % (s.value * scale), 17, UiKit.DIM)
	shown.custom_minimum_size.x = 64
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(func(v: float) -> void:
		shown.text = fmt % (v * scale)
		Settings.set_value(key, v))
	row.add_child(s)
	row.add_child(shown)
	_row(page, text, row)


func _options(page: VBoxContainer, text: String, key: String, items: Array) -> OptionButton:
	var o := OptionButton.new()
	for item: String in items:
		o.add_item(item)
	o.select(clampi(int(Settings.get_value(key)), 0, items.size() - 1))
	o.item_selected.connect(func(i: int) -> void: Settings.set_value(key, i))
	_row(page, text, o)
	return o


func _check(page: VBoxContainer, text: String, key: String) -> void:
	var c := CheckBox.new()
	c.button_pressed = bool(Settings.get_value(key))
	c.text = "On" if c.button_pressed else "Off"
	c.toggled.connect(func(on: bool) -> void:
		c.text = "On" if on else "Off"
		Settings.set_value(key, on))
	_row(page, text, c)


func _audio_tab() -> void:
	var page := _page("Audio")
	_slider(page, "Master volume", "master")
	_slider(page, "Sound effects", "effects")
	_slider(page, "Music", "music")
	_slider(page, "Crew voices", "voice")


func _graphics_tab() -> void:
	var page := _page("Graphics")
	var res: Array[String] = []
	for r in GameSettings.RESOLUTIONS:
		res.append("%d × %d" % [r.x, r.y])
	var resolution: OptionButton
	var window := _options(page, "Window", "window", GameSettings.WINDOW_MODES)
	resolution = _options(page, "Window size", "resolution", res)
	resolution.disabled = window.selected != 0
	window.item_selected.connect(func(i: int) -> void: resolution.disabled = i != 0)
	var q: Array[String] = []
	for item: Array in GameSettings.QUALITIES:
		q.append(item[0])
	_options(page, "Quality", "quality", q)
	_check(page, "VSync", "vsync")
	var caps: Array[String] = []
	for c in GameSettings.FPS_CAPS:
		caps.append("Unlimited" if c == 0 else "%d" % c)
	_options(page, "Frame rate cap", "fps_cap", caps)
	_slider(page, "Field of view", "fov", 60.0, 100.0, 1.0, "%d°", 1.0)


func _controls_tab() -> void:
	var page := _page("Controls")
	_slider(page, "Mouse sensitivity", "sensitivity", 0.25, 3.0, 0.05, "%.2f×", 1.0)
	_check(page, "Invert mouse Y", "invert_y")
	page.add_child(UiKit.label("Click a key, then press the new one (Esc cancels).", 15, UiKit.DIM))
	_key_buttons.clear()
	for action: String in Controls.REBINDABLE:
		var b := Button.new()
		b.pressed.connect(func() -> void:
			_waiting = action
			_refresh_keys())
		_key_buttons[action] = b
		_row(page, Controls.REBINDABLE[action], b)
	var reset := Button.new()
	reset.text = "Reset keys to defaults"
	reset.pressed.connect(func() -> void:
		Settings.reset_keys()
		_refresh_keys())
	page.add_child(reset)
	var note := UiKit.label("Esc always pauses. Each station's own keys are shown on its panel.", 15, UiKit.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(note)
	_refresh_keys()


func _refresh_keys() -> void:
	for action: String in _key_buttons:
		var b: Button = _key_buttons[action]
		b.text = "press a key..." if action == _waiting else OS.get_keycode_string(Settings.key_for(action))
		b.modulate = UiKit.WARN if action == _waiting else Color.WHITE
