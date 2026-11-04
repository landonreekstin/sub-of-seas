class_name ReactorStation
extends Station
## The Typhoon's reactor controls at the after end of the turbine room. She runs herself: this
## shows both reactors and the power they make. Broken, the reactors trip and she crawls on the
## emergency motors until someone fixes it.

var _label: Label3D
var _lines: Array[Label] = []


func _ready() -> void:
	Build.box(self, Vector3(0.15, 1.7, 1.7), Vector3(0.1, 1.15, 0), Color("#4A5248"))
	Build.label(self, "РЕАКТОРЫ", Vector3(-0.03, 1.9, 0), 30, UiKit.BRASS).rotation.y = -PI / 2.0
	_label = Build.label(self, "", Vector3(-0.03, 1.55, 0), 44)
	_label.rotation.y = -PI / 2.0
	for z in [-0.4, 0.4]:
		Build.sphere(self, 0.06, Vector3(-0.02, 1.15, z), UiKit.GOOD, 1.5)
	Build.hitbox(self, Vector3(0.6, 1.9, 1.8), Vector3(0.05, 0.95, 0))
	set_view(Vector3(-1.1, 1.6, 0), Vector3(0.1, 1.4, 0))


func _power() -> int:
	var sub := Sim.world.sub
	return roundi(30.0 + 70.0 * clampf(absf(sub.speed) / (sub.data.submerged_speed_kn * SubState.KNOT), 0.0, 1.0))


func _process(_delta: float) -> void:
	if Sim.world == null:
		return
	var down := Sim.world.sub.reactor_down
	_label.text = "SCRAM" if down else "%d%%" % _power()
	_label.modulate = UiKit.BAD if down else UiKit.CREAM
	if overlay != null and _lines.size() == 2:
		_lines[0].text = "REACTORS TRIPPED: emergency motors only. Repair these controls." if down else "Both reactors on line, %d%% power." % _power()


func _build_overlay(root: Control) -> void:
	var box := UiKit.bottom_panel(root)
	_lines.clear()
	_lines.append(UiKit.label("", 20))
	_lines.append(UiKit.label(footer(false), 14, UiKit.DIM))
	for l in _lines:
		box.add_child(l)
