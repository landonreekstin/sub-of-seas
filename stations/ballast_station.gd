class_name BallastStation
extends Station
## The ballast manifold: vents flood the main ballast tanks so she can dive, high-pressure
## air blows them so she surfaces. The "Christmas tree" lights show the tanks: red flooded
## (or vents open), green dry.

const TANKS := 4

var _lights: Array[MeshInstance3D] = []
var _air_label: Label3D
var _vent_lever: Node3D
var _blow_wheel: Node3D
var _lines: Array[Label] = []
var _confirm_until := 0.0 ## emergency blow asks for a second press


func _ready() -> void:
	# Faces -X (port side of the control room, facing outboard), like the dive station.
	Build.box(self, Vector3(0.2, 1.4, 2.0), Vector3(-0.05, 1.2, 0), Color("#3A3F38"))
	Build.box(self, Vector3(0.04, 0.32, 1.0), Vector3(0.07, 1.72, -0.35), Color("#151515"), false)
	var tree := Build.label(self, "MAIN BALLAST", Vector3(0.1, 1.95, -0.35), 26, UiKit.BRASS)
	tree.rotation.y = PI / 2.0
	for i in TANKS:
		_lights.append(Build.sphere(self, 0.05, Vector3(0.1, 1.68, -0.7 + i * 0.23), Color("#2A2A26")))
	Build.box(self, Vector3(0.04, 0.32, 0.5), Vector3(0.07, 1.72, 0.6), Color("#151515"), false)
	Build.label(self, "HP AIR", Vector3(0.1, 1.82, 0.6), 24, UiKit.BRASS).rotation.y = PI / 2.0
	_air_label = Build.label(self, "", Vector3(0.1, 1.66, 0.6), 44)
	_air_label.rotation.y = PI / 2.0
	_vent_lever = Node3D.new()
	_vent_lever.position = Vector3(0.1, 1.0, -0.5)
	add_child(_vent_lever)
	Build.box(_vent_lever, Vector3(0.04, 0.36, 0.04), Vector3(0, 0.18, 0), Color("#B23A2E"), false)
	Build.label(self, "VENTS", Vector3(0.1, 0.72, -0.5), 24).rotation.y = PI / 2.0
	_blow_wheel = Build.wheel(self, 0.16, Vector3(0.1, 1.05, 0.35), Color("#C9A04A"), Vector3.RIGHT)
	Build.label(self, "BLOW", Vector3(0.1, 0.72, 0.35), 24).rotation.y = PI / 2.0
	Build.box(self, Vector3(0.06, 0.14, 0.14), Vector3(0.1, 1.05, 0.8), Color("#B23A2E"), false) # emergency
	Build.hitbox(self, Vector3(0.6, 1.6, 2.0), Vector3(0.1, 1.1, 0))
	set_view(Vector3(1.4, 1.6, 0.05), Vector3(0, 1.4, 0.05))


func _process(delta: float) -> void:
	if Sim.world == null:
		return
	var sub := Sim.world.sub
	for i in _lights.size():
		var flooded := sub.ballast > (i + 0.5) / TANKS
		var lamp := Color("#E0533F") if flooded or sub.vents_open else Color("#8FD47A")
		_lights[i].material_override = Build.mat(lamp, 0.5)
	_air_label.text = "%d%%" % roundi(sub.hp_air * 100.0)
	_vent_lever.rotation.x = 0.6 if sub.vents_open else -0.6
	if sound_on_change("vents", sub.vents_open, "lever") and sub.vents_open:
		Sfx.play_at(self, "vent_rush", Vector3(0, 2.0, 0), 2.0)
	sound_on_change("blow", sub.blowing, "lever")
	sound_while("blow", "blow_loop", [0.0, 0.6, 1.0][clampi(sub.blowing, 0, 2)], Vector3(0, 1.8, 0), 4.0)
	if sub.blowing > 0:
		_blow_wheel.rotate_object_local(Vector3.FORWARD, delta * (8.0 if sub.blowing == 2 else 3.0))
	if overlay != null:
		_update_overlay(sub)


func _update_overlay(sub: SubState) -> void:
	var state := "FLOODED" if sub.ballast >= 0.99 else ("DRY" if sub.ballast <= 0.01 else "%d%% FULL" % roundi(sub.ballast * 100.0))
	if sub.blowing == 2:
		state += "  — EMERGENCY BLOW"
	elif sub.blowing == 1:
		state += "  — BLOWING"
	elif sub.vents_open and sub.ballast < 0.99:
		state += "  — FLOODING"
	_lines[0].text = "MAIN BALLAST  %s" % state
	_lines[1].text = "VENTS %-6s [V]     BLOW [B]     EMERGENCY BLOW [X]" % ("OPEN" if sub.vents_open else "SHUT")
	_lines[2].text = "HP AIR  %3d%%   (the compressors refill it surfaced, on the diesels)" % roundi(sub.hp_air * 100.0)
	_lines[2].add_theme_color_override("font_color", UiKit.BAD if sub.hp_air < 0.15 else UiKit.CREAM)
	if Time.get_ticks_msec() / 1000.0 < _confirm_until:
		_lines[3].text = "Press X again to blow everything. It uses a third of the air."
		_lines[3].add_theme_color_override("font_color", UiKit.BAD)
	elif sub.vents_open and sub.ballast < 0.95:
		_lines[3].text = "Flooding: she settles to decks awash, then the planes can take her down."
		_lines[3].add_theme_color_override("font_color", UiKit.DIM)
	elif sub.ballast >= 0.95:
		_lines[3].text = "Tanks full: the planes can take her down. Blow to surface."
		_lines[3].add_theme_color_override("font_color", UiKit.DIM)
	else:
		_lines[3].text = "Tanks dry: she floats. Open the vents to dive."
		_lines[3].add_theme_color_override("font_color", UiKit.DIM)


func _build_overlay(root: Control) -> void:
	var box := UiKit.bottom_panel(root)
	box.add_child(UiKit.label("BALLAST", 22, UiKit.BRASS))
	_lines.clear()
	for i in 4:
		var l := UiKit.label()
		box.add_child(l)
		_lines.append(l)
	box.add_child(UiKit.label(footer(cluster != ""), 14, UiKit.DIM))


func station_input(event: InputEvent) -> void:
	var sub := Sim.world.sub
	if key_pressed(event, KEY_V):
		order("shut" if sub.vents_open else "vent")
	elif key_pressed(event, KEY_B):
		order("stop" if sub.blowing == 1 else "blow")
	elif key_pressed(event, KEY_X):
		var now := Time.get_ticks_msec() / 1000.0
		if now < _confirm_until:
			_confirm_until = 0.0
			order("emergency")
		else:
			_confirm_until = now + 2.0
