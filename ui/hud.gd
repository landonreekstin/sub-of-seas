class_name Hud
extends CanvasLayer
## Minimal HUD: crosshair, interaction prompt, announcements, and the station overlay slot.

var _root: Control
var _crosshair: Label
var _prompt: Label
var _message: Label
var _status: Label
var _overlay: Control
var _message_tween: Tween
var _debrief: Control
var _objective: PanelContainer
var _objective_title: Label
var _objective_text: Label


func _ready() -> void:
	_root = UiKit.overlay_root()
	_root.theme = UiKit.theme()
	add_child(_root)
	_overlay = UiKit.overlay_root()
	_root.add_child(_overlay)

	_crosshair = UiKit.label("·", 28)
	_root.add_child(_crosshair)
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crosshair.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_crosshair.grow_vertical = Control.GROW_DIRECTION_BOTH

	_prompt = UiKit.label("", 20)
	_root.add_child(_prompt)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.offset_top = 40
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)

	_message = UiKit.label("", 26, UiKit.BRASS)
	_root.add_child(_message)
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.offset_top = 70
	_message.add_theme_constant_override("outline_size", 8)
	_message.add_theme_color_override("font_outline_color", Color.BLACK)

	_status = UiKit.label("", 14, UiKit.CREAM)
	_status.add_theme_constant_override("outline_size", 5)
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_root.add_child(_status)
	_status.position = Vector2(12, 8)


## The training checklist panel, top right. An empty title hides it.
func set_objective(title: String, text: String) -> void:
	if _objective == null:
		if title == "":
			return
		_objective = UiKit.panel()
		_root.add_child(_objective)
		_objective.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_objective.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_objective.offset_right = -12
		_objective.offset_top = 36
		var box := VBoxContainer.new()
		_objective.add_child(box)
		_objective_title = UiKit.label("", 16, UiKit.BRASS)
		box.add_child(_objective_title)
		_objective_text = UiKit.label("", 17)
		_objective_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_objective_text.custom_minimum_size = Vector2(360, 0)
		box.add_child(_objective_text)
	_objective.visible = title != ""
	_objective_title.text = title
	_objective_text.text = text


func set_prompt(text: String) -> void:
	_prompt.text = text


func set_status(text: String) -> void:
	_status.text = text


func show_message(text: String, seconds := 5.0) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	if _message_tween != null:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(seconds)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 1.0)


## Replaces the station overlay (null clears it). The crosshair hides while one is up.
func show_overlay(c: Control) -> void:
	for child in _overlay.get_children():
		child.queue_free()
	if c != null:
		_overlay.add_child(c)
	_crosshair.visible = c == null


func has_debrief() -> bool:
	return _debrief != null


## End-of-patrol screen for everyone aboard.
func show_debrief(crew: Dictionary) -> void:
	_debrief = UiKit.overlay_root()
	_root.add_child(_debrief)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_debrief.add_child(dim)
	var p := UiKit.panel()
	_debrief.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	p.add_child(box)
	var lost: bool = crew.result == "lost"
	var title := "BOAT LOST" if lost else ("TRAINING COMPLETE" if crew.result == "training" else "PATROL COMPLETE")
	box.add_child(UiKit.label(title, 34, UiKit.BAD if lost else UiKit.GOOD))
	box.add_child(UiKit.label(crew.result_text, 20))
	box.add_child(UiKit.label(" ", 8))
	var st: Dictionary = crew.stats
	var minutes := int(crew.time) / 60
	for line in [
		"Time on patrol        %d:%02d" % [minutes, int(crew.time) % 60],
		"Ships sunk            %d" % crew.sunk,
		"Tonnage               %d t" % crew.tonnage,
		"Depth charges felt    %d" % st.charges,
		"Leaks welded          %d" % st.leaks,
		"Fires put out         %d" % st.fires,
		"Repairs               %d" % st.repairs,
		"Crew                  %s" % ", ".join(crew.names.values()),
	]:
		box.add_child(UiKit.label(line, 18))
	box.add_child(UiKit.label(" ", 8))
	box.add_child(UiKit.label("[F10] back to the menu", 16, UiKit.DIM))
	_crosshair.visible = false
	_prompt.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
