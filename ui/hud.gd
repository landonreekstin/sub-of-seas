class_name Hud
extends CanvasLayer
## Minimal HUD: crosshair, interaction prompt, announcements, and the station overlay slot.

var _root: Control
var _crosshair: Label
var _prompt: Label
var _message: Label
var _call: RichTextLabel
var _call_tween: Tween
var _status: Label
var _overlay: Control
var _message_tween: Tween
var _debrief: Control
var _objective: PanelContainer
var _objective_title: Label
var _objective_text: Label
var _smoke: ColorRect
var _vignette: ColorRect
var _blackout: ColorRect
var _talk: Label


func _ready() -> void:
	_root = UiKit.overlay_root()
	_root.theme = UiKit.theme()
	add_child(_root)
	_build_air_layers()
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
	_message.offset_left = -430
	_message.offset_right = 430
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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


const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	float d = distance(UV, vec2(0.5)) * 1.6;
	float a = smoothstep(1.0 - amount * 0.9, 1.25 - amount * 0.6, d) * (0.4 + 0.6 * amount);
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
"""


## Full-screen layers for breathing bad air: grey smoke, a dark closing vignette, and the
## black of passing out.
func _build_air_layers() -> void:
	_smoke = ColorRect.new()
	_smoke.color = Color(0.45, 0.45, 0.43, 0.0)
	_vignette = ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = VIGNETTE_SHADER
	_vignette.material = m
	_blackout = ColorRect.new()
	_blackout.color = Color(0, 0, 0, 0.96)
	_blackout.visible = false
	var l := UiKit.label("You passed out...", 30, UiKit.DIM)
	_blackout.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	for c: ColorRect in [_smoke, _vignette, _blackout]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(c)
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## `bad` 0..1 (1 = about to pass out), `smoke` 0..1 where you stand.
func set_air(bad: float, smoke: float, knocked: bool) -> void:
	_smoke.color.a = clampf(smoke * 0.75, 0.0, 0.75)
	(_vignette.material as ShaderMaterial).set_shader_parameter("amount", bad)
	_vignette.visible = bad > 0.01
	_blackout.visible = knocked


func set_talking(on: bool) -> void:
	if _talk == null:
		_talk = UiKit.label("● TALKING", 16, UiKit.BAD)
		_root.add_child(_talk)
		_talk.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		_talk.offset_left = 14
		_talk.offset_top = -34
	_talk.visible = on


func set_prompt(text: String) -> void:
	_prompt.text = text


func set_status(text: String) -> void:
	_status.text = text


## A call from a crewmate the training stands in for ("Captain: come to 090"): big, under
## the message line, with a bell like an order over the boat's speakers.
func crew_call(who: String, text: String, seconds := 9.0) -> void:
	if _call == null:
		_call = RichTextLabel.new()
		_call.bbcode_enabled = true
		_call.fit_content = true
		_call.scroll_active = false
		_call.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_call.add_theme_font_size_override("normal_font_size", 30)
		_call.add_theme_font_size_override("bold_font_size", 30)
		_call.add_theme_constant_override("outline_size", 8)
		_call.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_root.add_child(_call)
		_call.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_call.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_call.offset_top = 210
		_call.offset_left = -460
		_call.offset_right = 460
	_call.text = "[center][b][color=#%s]%s:[/color][/b] [color=#%s]\"%s\"[/color][/center]" % [
		UiKit.BRASS.to_html(false), who.to_upper(), UiKit.CREAM.to_html(false), text]
	_call.modulate.a = 1.0
	Sfx.play("telegraph_ding", -6.0, 1.35)
	if _call_tween != null:
		_call_tween.kill()
	_call_tween = create_tween()
	_call_tween.tween_interval(seconds)
	_call_tween.tween_property(_call, "modulate:a", 0.0, 1.5)


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
func show_debrief(crew: Dictionary, career := "") -> void:
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
	var titles := {"lost": "BOAT LOST", "training": "TRAINING COMPLETE", "escaped": "PATROL OVER", "complete": "PATROL COMPLETE"}
	var m := MissionData.load_key(crew.mission)
	box.add_child(UiKit.label(titles.get(crew.result, "PATROL OVER"), 34, UiKit.BAD if lost else (UiKit.WARN if crew.result == "escaped" else UiKit.GOOD)))
	if m != null:
		box.add_child(UiKit.label("%s  ·  %s" % [m.title, Realism.level(crew.get("realism", "arcade")).title], 18, UiKit.BRASS))
	box.add_child(UiKit.label(crew.result_text, 20))
	box.add_child(UiKit.label(" ", 8))
	var done := 0
	for o: Dictionary in crew.get("objectives", []):
		done += int(o.get("done", false))
		box.add_child(UiKit.label("%s  %s" % ["✓" if o.get("done", false) else "✗", o.text], 18, UiKit.GOOD if o.get("done", false) else UiKit.DIM))
	if not crew.get("objectives", []).is_empty():
		box.add_child(UiKit.label(" ", 8))
	var st: Dictionary = crew.stats
	var minutes := int(crew.time) / 60
	var sunk_list: Array[String] = []
	for k: String in crew.get("sunk_by", {}):
		var d: ShipClassData = load("res://data/ships/%s.tres" % k)
		sunk_list.append("%d × %s" % [crew.sunk_by[k], d.display_name])
	for line in [
		"Time on patrol        %d:%02d" % [minutes, int(crew.time) % 60],
		"Ships sunk            %d%s" % [crew.sunk, ("  (" + ", ".join(sunk_list) + ")") if not sunk_list.is_empty() else ""],
		"Tonnage               %d t" % crew.tonnage,
		"Depth charges felt    %d" % st.charges,
		"Shell hits taken      %d" % st.get("shells", 0),
		"Leaks welded          %d" % st.leaks,
		"Fires put out         %d" % st.fires,
		"Repairs               %d" % st.repairs,
		"Crew                  %s" % ", ".join(crew.names.values()),
	]:
		box.add_child(UiKit.label(line, 18))
	if career != "":
		box.add_child(UiKit.label(" ", 8))
		box.add_child(UiKit.label(career, 18, UiKit.BRASS))
	box.add_child(UiKit.label(" ", 8))
	box.add_child(UiKit.label("[F10] back to the menu", 16, UiKit.DIM))
	_crosshair.visible = false
	_prompt.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
