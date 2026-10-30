class_name EngineStation
extends Station
## The diesel control panel at the after end of the engine room: start and stop each
## diesel (1/2) and watch the battery. Diesels need air, so they only run surfaced.

const LAMP_OFF := Color("#2A2A26")
const LAMP_CRANK := Color("#E8B04A")
const LAMP_ON := Color("#8FD47A")

var _levers: Array[Node3D] = []
var _lamps: Array[MeshInstance3D] = []
var _battery_label: Label3D
var _lines: Array[Label] = []


func _ready() -> void:
	# Faces -X: the panel is on local +X, the engineer stands on local -X.
	Build.box(self, Vector3(0.15, 1.7, 1.7), Vector3(0.1, 1.15, 0), Color("#4A5248"))
	Build.box(self, Vector3(0.04, 0.42, 0.9), Vector3(0.0, 1.78, 0), Color("#151515"), false)
	Build.label(self, "BATTERY", Vector3(-0.03, 1.92, 0), 28, UiKit.BRASS).rotation.y = -PI / 2.0
	_battery_label = Build.label(self, "", Vector3(-0.03, 1.72, 0), 72)
	_battery_label.rotation.y = -PI / 2.0
	for i in 2:
		var z := -0.42 if i == 0 else 0.42
		Build.label(self, "No. %d" % (i + 1), Vector3(-0.03, 1.38, z), 32).rotation.y = -PI / 2.0
		_lamps.append(Build.sphere(self, 0.06, Vector3(-0.02, 1.22, z), LAMP_OFF))
		Build.box(self, Vector3(0.06, 0.12, 0.2), Vector3(-0.01, 0.82, z), Color("#3A3F38"), false)
		var lever := Node3D.new()
		lever.position = Vector3(-0.04, 0.82, z)
		add_child(lever)
		Build.box(lever, Vector3(0.04, 0.32, 0.04), Vector3(0, 0.16, 0), UiKit.BRASS, false)
		Build.sphere(lever, 0.045, Vector3(0, 0.33, 0), Color("#B23A2E"))
		_levers.append(lever)
	Build.hitbox(self, Vector3(0.6, 1.8, 1.8), Vector3(-0.1, 0.9, 0))
	set_view(Vector3(-1.35, 1.6, 0), Vector3(0.1, 1.3, 0))


func _process(_delta: float) -> void:
	if Sim.world == null:
		return
	var sub := Sim.world.sub
	for i in _lamps.size():
		var d: float = sub.diesels[i]
		var lamp_color := LAMP_ON if d >= 1.0 else (LAMP_CRANK if d > 0.0 else LAMP_OFF)
		if d > 0.0 and d < 1.0 and Time.get_ticks_msec() % 400 < 200:
			lamp_color = LAMP_OFF # blinks while cranking
		_lamps[i].material_override = Build.mat(lamp_color, 0.0 if lamp_color == LAMP_OFF else 0.5)
		_levers[i].rotation.z = 0.5 if d > 0.0 else -0.5 # thrown towards the engineer when on
		if sound_on_change("diesel%d" % i, d > 0.0, "lever") and d > 0.0:
			Sfx.play_at(self, "diesel_start", Vector3(0, 1.0, 0), 2.0)
	_battery_label.text = "%d%%" % roundi(sub.battery * 100.0)
	_battery_label.modulate = _battery_color(sub.battery)
	if overlay != null:
		_update_overlay(sub)


func _update_overlay(sub: SubState) -> void:
	for i in 2:
		var d: float = sub.diesels[i]
		var state := "RUNNING" if d >= 1.0 else ("STARTING..." if d > 0.0 else "STOPPED")
		_lines[i].text = "No. %d DIESEL   %-12s [%d] %s" % [i + 1, state, i + 1, "stop" if d > 0.0 else "start"]
		_lines[i].add_theme_color_override("font_color", UiKit.GOOD if d >= 1.0 else UiKit.CREAM)
	var per_min := sub.charge_rate * 6000.0
	var rate := ""
	if sub.charge_rate > 0.0 and sub.battery >= 1.0:
		rate = "FULLY CHARGED"
	elif sub.charge_rate > 0.0:
		rate = "CHARGING  %+.1f %%/min" % per_min
	elif sub.charge_rate < 0.0 and sub.battery > 0.0:
		rate = "DRAINING  %.1f %%/min   (%d min left at this speed)" % [per_min, ceili(sub.battery / -sub.charge_rate / 60.0)]
	_lines[2].text = "BATTERY  %3d%%   %s" % [roundi(sub.battery * 100.0), rate]
	_lines[2].add_theme_color_override("font_color", _battery_color(sub.battery))
	if sub.depth > SubState.INDUCTION_DEPTH:
		_lines[3].text = "Submerged: the diesels need air. Surface first."
	elif sub.diesels_running() > 0:
		_lines[3].text = "Stop the diesels BEFORE diving, or they flood."
	else:
		_lines[3].text = "Surfaced: start the diesels to charge the battery."
	_lines[3].add_theme_color_override("font_color", UiKit.WARN if sub.diesels_running() > 0 else UiKit.DIM)


static func _battery_color(b: float) -> Color:
	return UiKit.BAD if b <= 0.1 else (UiKit.WARN if b <= 0.2 else UiKit.CREAM)


func _build_overlay(root: Control) -> void:
	var box := UiKit.bottom_panel(root)
	box.add_child(UiKit.label("ENGINE ROOM", 22, UiKit.BRASS))
	_lines.clear()
	for i in 4:
		var l := UiKit.label()
		box.add_child(l)
		_lines.append(l)
	box.add_child(UiKit.label(footer(cluster != ""), 14, UiKit.DIM))


func station_input(event: InputEvent) -> void:
	for i in 2:
		if key_pressed(event, [KEY_1, KEY_2][i]):
			order("diesel", [i, Sim.world.sub.diesels[i] == 0.0])
