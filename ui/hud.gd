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
