class_name AirStation
extends Station
## The air panel: CO2 and O2 gauges, the CO2 scrubber (load a fresh absorbent canister)
## and the oxygen bleed valve from the oxygen bank.

var _co2_label: Label3D
var _o2_label: Label3D
var _bleed_wheel: Node3D
var _scrubber_lamp: MeshInstance3D
var _lines: Array[Label] = []


func _ready() -> void:
	# Faces -X: panel on local +X, the operator stands on local -X.
	Build.box(self, Vector3(0.15, 1.5, 1.4), Vector3(0.1, 1.15, 0), Color("#4A5248"))
	for i in 2:
		var z := -0.33 if i == 0 else 0.33
		Build.box(self, Vector3(0.04, 0.36, 0.56), Vector3(0.0, 1.62, z), Color("#151515"), false)
		Build.label(self, "CO2 %" if i == 0 else "OXYGEN %", Vector3(-0.03, 1.73, z), 26, UiKit.BRASS).rotation.y = -PI / 2.0
		var l := Build.label(self, "", Vector3(-0.03, 1.56, z), 52)
		l.rotation.y = -PI / 2.0
		if i == 0:
			_co2_label = l
		else:
			_o2_label = l
	# Scrubber canister housing and the bleed valve.
	Build.cyl(self, 0.16, 0.5, Vector3(-0.08, 0.95, -0.33), Color("#8A8F86"))
	_scrubber_lamp = Build.sphere(self, 0.04, Vector3(-0.08, 1.25, -0.33), Color("#2A2A26"))
	_bleed_wheel = Build.wheel(self, 0.14, Vector3(-0.02, 1.05, 0.33), Color("#3A6EA5"), Vector3.LEFT)
	Build.cyl(self, 0.12, 0.9, Vector3(0.05, 0.45, 0.33), Color("#3A6EA5")) # oxygen flask
	Build.hitbox(self, Vector3(0.6, 1.6, 1.5), Vector3(-0.1, 0.9, 0))
	set_view(Vector3(-1.2, 1.55, 0), Vector3(0.1, 1.3, 0))


func _process(delta: float) -> void:
	if Sim.world == null:
		return
	var air := Sim.world.air
	_co2_label.text = "%.1f" % air.co2
	_co2_label.modulate = _co2_color(air.co2)
	_o2_label.text = "%.1f" % air.o2
	_o2_label.modulate = _o2_color(air.o2)
	_scrubber_lamp.material_override = Build.mat(Color("#8FD47A") if air.canister_left > 0.0 else Color("#2A2A26"), 0.5 if air.canister_left > 0.0 else 0.0)
	if air.bleed:
		_bleed_wheel.rotate_object_local(Vector3.FORWARD, delta * 2.0)
	if overlay != null:
		_lines[0].text = "CO2     %4.1f %%   OXYGEN  %4.1f %%" % [air.co2, air.o2]
		_lines[0].add_theme_color_override("font_color", _co2_color(air.co2) if air.co2 >= AirState.CO2_BAD else _o2_color(air.o2))
		var scrub := "working, %d:%02d left" % [int(air.canister_left) / 60, int(air.canister_left) % 60] if air.canister_left > 0.0 else "EMPTY"
		_lines[1].text = "SCRUBBER %-22s [C] fresh canister (%d left)" % [scrub, air.canisters]
		_lines[2].text = "OXYGEN BLEED %-5s [O]   bank %d%%" % ["OPEN" if air.bleed else "SHUT", roundi(air.o2_bank * 100.0)]
		_lines[3].text = "Past %d%% CO2 or under %d%% oxygen the crew flags; at %d%% / %d%% they pass out. Surfacing clears it." % [
			int(AirState.CO2_BAD), int(AirState.O2_BAD), int(AirState.CO2_OUT), int(AirState.O2_OUT)]


static func _co2_color(v: float) -> Color:
	return UiKit.BAD if v >= 4.5 else (UiKit.WARN if v >= AirState.CO2_BAD else UiKit.CREAM)


static func _o2_color(v: float) -> Color:
	return UiKit.BAD if v <= 15.5 else (UiKit.WARN if v <= AirState.O2_BAD else UiKit.CREAM)


func _build_overlay(root: Control) -> void:
	var box := UiKit.bottom_panel(root)
	box.add_child(UiKit.label("AIR", 22, UiKit.BRASS))
	_lines.clear()
	for i in 4:
		var l := UiKit.label()
		box.add_child(l)
		_lines.append(l)
	_lines[3].add_theme_color_override("font_color", UiKit.DIM)
	box.add_child(UiKit.label(footer(cluster != ""), 14, UiKit.DIM))


func station_input(event: InputEvent) -> void:
	if key_pressed(event, KEY_C):
		order("canister")
	elif key_pressed(event, KEY_O):
		order("bleed", not Sim.world.air.bleed)
