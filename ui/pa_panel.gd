class_name PaPanel
extends Control
## The PA microphone: type what you want and press Enter; the host's crew carry it out (BotCrew).


var _edit: LineEdit


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiKit.bottom_panel(self)
	box.add_child(UiKit.label("PA: ALL HANDS", 22, UiKit.BRASS))
	_edit = LineEdit.new()
	_edit.placeholder_text = "Type your order and press Enter"
	_edit.max_length = 160
	_edit.custom_minimum_size = Vector2(760, 0)
	_edit.text_submitted.connect(_send)
	box.add_child(_edit)
	# Every order the crew know, by kind (CrewCommand.HELP); say them your own way, or join
	# several with "and" / "then".
	var cols := GridContainer.new()
	cols.columns = 4 # two rows: it fits a small screen
	cols.add_theme_constant_override("h_separation", 28)
	cols.add_theme_constant_override("v_separation", 8)
	box.add_child(cols)
	for group: Array in CrewCommand.HELP:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		cols.add_child(col)
		col.add_child(UiKit.label(group[0].to_upper(), 14, UiKit.BRASS))
		for pair: Array in group[1]:
			col.add_child(UiKit.label("\"%s\"" % pair[0], 13, UiKit.DIM))
	box.add_child(UiKit.label("Say it your own way, or join orders: \"come to 090 and full speed\".", 14, UiKit.DIM))
	box.add_child(UiKit.label("[Enter] send    [Esc] put the mic back", 14, UiKit.DIM))
	_edit.grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func _send(text: String) -> void:
	if text.strip_edges() != "":
		Game.instance.rq_pa.rpc_id(1, text.left(160))
	close()


func close() -> void:
	if Game.instance != null and Game.instance.pa_panel == self:
		Game.instance.pa_panel = null
	queue_free()
