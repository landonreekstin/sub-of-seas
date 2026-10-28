class_name UiKit
## Shared UI styling: cream type on dark panels with brass borders.

const CREAM := Color("#F2E8CF")
const DIM := Color("#A89F88")
const DARK := Color(0.07, 0.08, 0.07, 0.9)
const BRASS := Color("#C9A04A")
const GOOD := Color("#8FD47A")
const WARN := Color("#E8B04A")
const BAD := Color("#E0533F")

static var _theme: Theme


static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Courier New", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
		font.font_weight = 600
		_theme.default_font = font
		_theme.default_font_size = 18
		_theme.set_color("font_color", "Label", CREAM)
	return _theme


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = DARK
	sb.border_color = BRASS
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", sb)
	return p


static func label(text := "", size := 18, color := CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## A panel pinned to the bottom centre of a full-screen overlay, holding a VBox.
static func bottom_panel(overlay: Control) -> VBoxContainer:
	var p := panel()
	overlay.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_bottom = -24
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	p.add_child(box)
	return box


static func overlay_root() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
