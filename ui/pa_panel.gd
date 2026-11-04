class_name PaPanel
extends Control
## The PA microphone: type what you want and press Enter; the host's crew carry it out (BotCrew).

const EXAMPLES := "\"sink the ship to the east\"   \"dive to the bottom of the ocean\"   \"come to 090, full speed\"\n\"battle stations\"   \"fix the damage\"   \"what's our objective\"   \"get us out of here\"   \"enemy sub\""

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
	box.add_child(UiKit.label(EXAMPLES, 15, UiKit.DIM))
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
