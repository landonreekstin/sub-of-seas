class_name BilgeStation
extends Station
## The fixed bilge pump (design: "fast, needs power, can break"), on the control room's
## forward bulkhead: [P] runs it. It draws from whichever compartment is wettest, four times
## the portable pump's rate, off the battery; and escorts can hear it.

var _lamp: MeshInstance3D
var _motor: Node3D
var _label: Label3D
var _lines: Array[Label] = []


func _ready() -> void:
	# Faces -X like the air panel: the panel on local +X, the operator on local -X.
	Build.box(self, Vector3(0.15, 1.05, 0.9), Vector3(0.1, 0.6, 0), Color("#4A5248"))
	Build.label(self, "BILGE PUMP", Vector3(-0.03, 1.02, 0), 26, UiKit.BRASS).rotation.y = -PI / 2.0
	_label = Build.label(self, "", Vector3(-0.03, 0.88, 0), 30)
	_label.rotation.y = -PI / 2.0
	_lamp = Build.sphere(self, 0.04, Vector3(-0.03, 0.88, 0.32), Color("#2A2A26"))
	# The motor and pump casing, a suction line down into the bilge.
	_motor = Node3D.new()
	_motor.position = Vector3(-0.12, 0.35, -0.15)
	add_child(_motor)
	Build.cyl(_motor, 0.15, 0.45, Vector3.ZERO, Color("#3A6EA5"), Vector3.BACK)
	for i in 4:
		Build.box(_motor, Vector3(0.32, 0.02, 0.02), Vector3(0, 0, -0.15 + i * 0.1), Color("#2B4E78"), false)
	Build.cyl(self, 0.06, 0.35, Vector3(-0.12, 0.17, 0.25), Color("#8A8F86"))
	Build.cyl(self, 0.05, 0.6, Vector3(-0.12, 0.35, 0.28), Color("#8A8F86"), Vector3.BACK)
	Build.box(self, Vector3(0.06, 0.16, 0.08), Vector3(-0.0, 0.62, 0.32), Color("#B23A2E"), false) # the switch
	Build.hitbox(self, Vector3(0.6, 1.1, 1.0), Vector3(-0.1, 0.55, 0))
	set_view(Vector3(-1.2, 1.35, 0), Vector3(0.1, 0.65, 0))


func _process(_delta: float) -> void:
	if Sim.world == null:
		return
	var hull := Sim.world.hull
	var running := hull.bilge_from >= 0
	_label.text = "RUNNING" if running else ("ON — DRY" if hull.bilge_on else "OFF")
	_label.modulate = UiKit.GOOD if running else UiKit.CREAM
	_lamp.material_override = Build.mat(Color("#8FD47A") if hull.bilge_on else Color("#2A2A26"), 0.6 if hull.bilge_on else 0.0)
	_motor.position.x = -0.12 + (randf_range(-1.0, 1.0) * 0.004 if running else 0.0)
	sound_on_change("on", hull.bilge_on, "lever")
	sound_while("pump", "motor_loop", 1.0 if running else 0.0, Vector3(-0.1, 0.4, 0), 2.0)
	if overlay != null:
		var wettest := "dry everywhere"
		if hull.bilge_from >= 0:
			wettest = "drawing from the %s (%d%%)" % [hull.comps[hull.bilge_from].name, roundi(hull.comps[hull.bilge_from].water * 100.0)]
		_lines[0].text = "BILGE PUMP  %s   [P] %s" % ["ON" if hull.bilge_on else "OFF", "stop" if hull.bilge_on else "start"]
		_lines[1].text = "Pumps the wettest compartment, 4× a portable pump: %s" % wettest
		_lines[2].text = "It runs off the battery (%d%%), and escorts can hear it: stop it when they're close." % roundi(Sim.world.sub.battery * 100.0)
		_lines[2].add_theme_color_override("font_color", UiKit.WARN if running else UiKit.DIM)


func _build_overlay(root: Control) -> void:
	var box := UiKit.bottom_panel(root)
	box.add_child(UiKit.label("BILGE PUMP", 22, UiKit.BRASS))
	_lines.clear()
	for i in 3:
		var l := UiKit.label()
		box.add_child(l)
		_lines.append(l)
	box.add_child(UiKit.label(footer(cluster != ""), 14, UiKit.DIM))


func station_input(event: InputEvent) -> void:
	if key_pressed(event, KEY_P):
		order("pump", not Sim.world.hull.bilge_on)
