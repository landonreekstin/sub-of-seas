class_name HelmStation
extends Station
## Steering wheel and engine telegraph. W/S telegraph, A/D rudder.

var _wheel: Node3D
var _telegraph_handle: Node3D
var _lines: Array[Label] = []


func _ready() -> void:
	# Faces +X (station stands on the starboard side of the control room facing outboard).
	Build.box(self, Vector3(0.3, 1.0, 0.5), Vector3(0.15, 0.5, 0), Color("#4A5248"))
	_wheel = Build.wheel(self, 0.42, Vector3(0.0, 1.25, 0), Color("#7A4A2A"), Vector3.LEFT)
	Build.box(self, Vector3(0.2, 1.1, 0.2), Vector3(0.2, 0.55, 0.65), Color("#3A3F38"))
	_telegraph_handle = Node3D.new()
	_telegraph_handle.position = Vector3(0.2, 1.15, 0.65)
	add_child(_telegraph_handle)
	Build.box(_telegraph_handle, Vector3(0.04, 0.3, 0.04), Vector3(0, 0.15, 0), Color("#C9A04A"), false)
	Build.cyl(self, 0.2, 0.06, Vector3(0.12, 1.15, 0.65), Color("#E8E0C8"), Vector3.RIGHT)
	Build.hitbox(self, Vector3(0.6, 1.6, 1.4), Vector3(0.1, 0.8, 0.3))
	set_view(Vector3(-0.85, 1.6, 0.25), Vector3(0.1, 1.15, 0.25))


func _process(_delta: float) -> void:
	if Sim.world == null:
		return
	var sub := Sim.world.sub
	_wheel.rotation.x = deg_to_rad(sub.rudder_angle() * 4.0)
	_telegraph_handle.rotation.x = deg_to_rad(-sub.telegraph * 20.0)
	if overlay != null:
		_lines[0].text = "TELEGRAPH  %-15s [W/S]" % SubState.TELEGRAPH_NAMES[sub.telegraph]
		var side := "AMIDSHIPS" if sub.rudder == 0 else ("%s %d°" % ["RIGHT" if sub.rudder > 0 else "LEFT", absf(sub.rudder_angle())])
		_lines[1].text = "RUDDER     %-15s [A/D]" % side
		_lines[2].text = "HEADING    %03d°   SPEED %4.1f kn   BATTERY %d%%" % [roundi(sub.heading) % 360, sub.speed / SubState.KNOT, roundi(sub.battery * 100.0)]
		_lines[2].add_theme_color_override("font_color", UiKit.BAD if sub.battery <= 0.1 else UiKit.CREAM)


func _build_overlay(root: Control) -> void:
	var box := UiKit.bottom_panel(root)
	box.add_child(UiKit.label("HELM", 22, UiKit.BRASS))
	_lines.clear()
	for i in 3:
		var l := UiKit.label()
		box.add_child(l)
		_lines.append(l)
	box.add_child(UiKit.label(footer(cluster != ""), 14, UiKit.DIM))


func station_input(event: InputEvent) -> void:
	# Orders are applied locally at once (so quick presses stack) and confirmed by the
	# host's next snapshot.
	var sub := Sim.world.sub
	if key_pressed(event, KEY_W):
		sub.telegraph = mini(sub.telegraph + 1, 4)
	elif key_pressed(event, KEY_S):
		sub.telegraph = maxi(sub.telegraph - 1, -2)
	elif key_pressed(event, KEY_A):
		sub.rudder = maxi(sub.rudder - 1, -3)
	elif key_pressed(event, KEY_D):
		sub.rudder = mini(sub.rudder + 1, 3)
	else:
		return
	order("telegraph", sub.telegraph)
	order("rudder", sub.rudder)
