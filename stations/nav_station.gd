class_name NavStation
extends Station
## The chart table in the control room. The plot fills the screen while you're on it:
## W/S zoom, LMB puts a pencil mark down for everyone, RMB rubs out the nearest one.

const ZOOMS := [1500.0, 3000.0, 6000.0, 12000.0, 25000.0]

var _zoom := 2
var _chart: ChartView


func _ready() -> void:
	# Faces -X like the other starboard stations: table on local +X.
	Build.box(self, Vector3(1.0, 0.9, 1.4), Vector3(0.0, 0.45, 0), Color("#6B5A44"))
	Build.box(self, Vector3(0.9, 0.02, 1.3), Vector3(0.0, 0.91, 0), Color("#E8DFC4"), false)
	Build.box(self, Vector3(0.04, 0.03, 0.9), Vector3(-0.1, 0.93, 0.05), Color("#2B5C8A"), false) # parallel rule
	Build.box(self, Vector3(0.5, 0.03, 0.03), Vector3(0.1, 0.93, -0.3), Color("#3B3A36"), false) # pencil line
	var l := Build.label(self, "CHART", Vector3(-0.51, 0.7, 0), 32, Color("#2B2B26"))
	l.rotation.y = -PI / 2.0
	Build.hitbox(self, Vector3(1.0, 1.0, 1.4), Vector3(0, 0.5, 0))
	set_view(Vector3(-0.9, 1.75, 0), Vector3(0.05, 0.9, 0))


func _build_overlay(root: Control) -> void:
	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, 40)
	root.add_child(frame)
	var box := VBoxContainer.new()
	frame.add_child(box)
	_chart = ChartView.new()
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart.half_width = ZOOMS[_zoom]
	_chart.clip_contents = true
	box.add_child(_chart)
	var home := "   [H] head home (ends the patrol)" if Game.instance.crew.mission == "sandbox" else ""
	var help := UiKit.label("CHART   [W/S] zoom   [LMB] pencil mark   [RMB] rub out   red: TDC   ◆ last marked   blue: sonar, soundings (m)%s    %s" % [home, footer(cluster != "")], 14, UiKit.CREAM)
	help.add_theme_constant_override("outline_size", 5)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	box.add_child(help)
	for c: Control in [frame, box, help]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE # clicks go to station_input


func on_enter() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func on_leave() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_chart = null
	super.on_leave()


func station_input(event: InputEvent) -> void:
	if _chart == null:
		return
	if key_pressed(event, KEY_H) and Game.instance.crew.mission == "sandbox":
		order("home")
		return
	if key_pressed(event, KEY_W) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP):
		_zoom = maxi(_zoom - 1, 0)
	elif key_pressed(event, KEY_S) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_zoom = mini(_zoom + 1, ZOOMS.size() - 1)
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var local: Vector2 = event.position - _chart.get_global_rect().position
		if Rect2(Vector2.ZERO, _chart.size).has_point(local):
			var at := _chart.to_world(local)
			order("pencil" if event.button_index == MOUSE_BUTTON_LEFT else "erase", [at.x, at.y])
			Sfx.play_at(self, "pencil", Vector3(0, 1.0, 0), 0.0, 1.0 if event.button_index == MOUSE_BUTTON_LEFT else 0.7)
		return
	else:
		return
	click(-6.0)
	_chart.half_width = ZOOMS[_zoom]
