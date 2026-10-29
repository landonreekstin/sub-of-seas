class_name DiveStation
extends Station
## Bow and stern planes. Sets the ordered depth; the planesmen hold it.

const PRESETS := {KEY_1: 0.0, KEY_2: -1.0, KEY_3: 45.0, KEY_4: -2.0} # -1 periscope, -2 test depth

var _wheels: Array[Node3D] = []
var _needle: Node3D
var _lines: Array[Label] = []


func _ready() -> void:
	# Faces -X (port side of the control room, facing outboard).
	Build.box(self, Vector3(0.25, 2.2, 1.6), Vector3(-0.15, 1.1, 0), Color("#4A5248"))
	_wheels.append(Build.wheel(self, 0.32, Vector3(0.05, 1.0, -0.4), Color("#B23A2E"), Vector3.RIGHT))
	_wheels.append(Build.wheel(self, 0.32, Vector3(0.05, 1.0, 0.4), Color("#B23A2E"), Vector3.RIGHT))
	# Depth gauge with a needle.
	Build.cyl(self, 0.3, 0.04, Vector3(-0.01, 1.85, 0), Color("#151515"), Vector3.RIGHT)
	Build.cyl(self, 0.32, 0.03, Vector3(-0.02, 1.85, 0), Color("#C9A04A"), Vector3.RIGHT)
	_needle = Node3D.new()
	_needle.position = Vector3(0.02, 1.85, 0)
	add_child(_needle)
	Build.box(_needle, Vector3(0.01, 0.24, 0.02), Vector3(0, 0.11, 0), Color("#F2E8CF"), false)
	var l := Build.label(self, "DEPTH", Vector3(0.03, 2.08, 0), 28)
	l.rotation.y = PI / 2.0
	Build.hitbox(self, Vector3(0.6, 2.2, 1.6), Vector3(0.1, 1.1, 0))
	set_view(Vector3(0.95, 1.6, 0), Vector3(0, 1.35, 0))


func _process(_delta: float) -> void:
	if Sim.world == null:
		return
	var sub := Sim.world.sub
	var planes := clampf((sub.ordered_depth - sub.depth) * 0.1, -1.0, 1.0)
	for w in _wheels:
		w.rotation.z = planes * 1.2
	_needle.rotation.x = -sub.depth / 150.0 * TAU * 0.9
	if overlay != null:
		_lines[0].text = "ORDERED DEPTH  %5.0f m      [W/S] ±5   [Shift] ±1" % sub.ordered_depth
		_lines[1].text = "DEPTH          %5.1f m      test %d / crush %d" % [sub.depth, sub.data.test_depth, sub.data.crush_depth]
		var cond := Sim.world.conditions
		var bt := "   BT: layer at %d m%s" % [roundi(cond.layer_depth), " — WE'RE UNDER IT" if cond.below_layer(sub.depth) else ""] if cond.layer_depth > 0.0 else "   BT: no layer"
		_lines[2].text = "[1] surface  [2] periscope depth %d m  [3] 45 m  [4] test depth%s" % [sub.data.periscope_depth, bt]
		_lines[1].add_theme_color_override("font_color", UiKit.BAD if sub.depth > sub.data.test_depth else UiKit.CREAM)


func _build_overlay(root: Control) -> void:
	var box := UiKit.bottom_panel(root)
	box.add_child(UiKit.label("DIVE PLANES", 22, UiKit.BRASS))
	_lines.clear()
	for i in 3:
		var l := UiKit.label()
		box.add_child(l)
		_lines.append(l)
	box.add_child(UiKit.label(footer(cluster != ""), 14, UiKit.DIM))


func station_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var sub := Sim.world.sub
	var step := 1.0 if event.shift_pressed else 5.0
	var key: Key = event.physical_keycode
	if key == KEY_W:
		sub.ordered_depth = maxf(sub.ordered_depth - step, 0.0)
	elif key == KEY_S:
		sub.ordered_depth += step
	elif PRESETS.has(key):
		var d: float = PRESETS[key]
		if d == -1.0:
			d = sub.data.periscope_depth
		elif d == -2.0:
			d = sub.data.test_depth
		sub.ordered_depth = d
	else:
		return
	order("depth", sub.ordered_depth) # applied locally now, confirmed by the host
