class_name TdcStation
extends Station
## The Torpedo Data Computer cabinet in the conning tower. It turns periscope marks into
## the target's course and speed, solves the gyro angle, and can drive the tubes' gyros.
## W/S nudge the speed estimate, A/D the course, C clears, T sends to the tubes (follow).

var _dials: Array[Label3D] = []
var _quality_bar: MeshInstance3D
var _lines: Array[Label] = []
var _bar: ColorRect ## fill of the quality meter


func _ready() -> void:
	# Faces -X: cabinet on local +X, the operator stands on local -X.
	Build.box(self, Vector3(0.5, 1.6, 1.3), Vector3(0.1, 0.8, 0), Color("#4A5248"))
	Build.box(self, Vector3(0.04, 0.5, 1.1), Vector3(-0.17, 1.25, 0), Color("#151515"), false)
	Build.label(self, "TDC", Vector3(-0.2, 1.58, 0), 40, UiKit.BRASS).rotation.y = -PI / 2.0
	var names := ["SPEED", "COURSE", "GYRO"]
	for i in 3:
		var z := -0.36 + i * 0.36
		Build.label(self, names[i], Vector3(-0.2, 1.42, z), 22, UiKit.DIM).rotation.y = -PI / 2.0
		var l := Build.label(self, "--", Vector3(-0.2, 1.24, z), 44)
		l.rotation.y = -PI / 2.0
		_dials.append(l)
	_quality_bar = Build.box(self, Vector3(0.02, 0.05, 1.0), Vector3(-0.2, 1.06, 0), UiKit.GOOD, false)
	for i in 6:
		Build.cyl(self, 0.04, 0.05, Vector3(-0.17, 0.75, -0.45 + i * 0.18), UiKit.BRASS, Vector3.LEFT)
	Build.hitbox(self, Vector3(0.6, 1.6, 1.3), Vector3(0.0, 0.8, 0))
	set_view(Vector3(-1.05, 1.5, 0), Vector3(0.1, 1.2, 0))


func _process(_delta: float) -> void:
	if Sim.world == null or Game.instance == null:
		return
	var sol: Dictionary = Game.instance.tdc_solution()
	var est: Dictionary = sol.est
	_dials[0].text = "%.0f kn" % est.speed_kn if est.ok else "--"
	_dials[1].text = "%03d°" % (roundi(est.course) % 360) if est.ok else "--"
	_dials[2].text = "%+d°" % roundi(sol.gyro) if sol.has("gyro") else "--"
	_dials[2].modulate = UiKit.GOOD if sol.ok else UiKit.WARN
	var q: float = sol.get("quality", 0.0)
	_quality_bar.scale.z = maxf(0.01, q)
	_quality_bar.material_override = Build.mat(_quality_color(q), 0.4)
	if overlay != null:
		_update_overlay(sol, est)


func _update_overlay(sol: Dictionary, est: Dictionary) -> void:
	var tdc: Dictionary = Game.instance.crew.tdc
	var ship := Sim.world.find_ship(int(tdc.target))
	var who := ship.data.display_name.to_upper() if ship != null else "TARGET (lost)"
	if tdc.marks.is_empty():
		_lines[0].text = "NO MARKS — the periscope marks a target with [M]"
	else:
		var age := Sim.world.time - float(tdc.marks[-1].t)
		_lines[0].text = "%s   %d mark%s, last %ds ago%s" % [who, tdc.marks.size(), "" if tdc.marks.size() == 1 else "s", roundi(age),
			"" if est.get("measured", false) else "   (one mark: speed and course are guesses)"]
	if est.ok:
		_lines[1].text = "TARGET SPEED  %4.1f kn   [W/S] ±1      COURSE  %03d°   [A/D] ±5" % [est.speed_kn, roundi(est.course) % 360]
		_lines[2].text = "RANGE NOW %5d m    AoB %s %d°    TORPEDO RUN %s" % [roundi(sol.range), "STBD" if sol.aob > 0 else "PORT",
			absi(roundi(sol.aob)), "%d m" % roundi(sol.run) if sol.has("run") else "--"]
	else:
		_lines[1].text = ""
		_lines[2].text = ""
	if sol.ok:
		_lines[3].text = "GYRO %+d°   %s" % [roundi(sol.gyro), "SENT — the tubes follow it  [T] stop" if tdc.follow else "[T] send to the tubes"]
		_lines[3].add_theme_color_override("font_color", UiKit.GOOD)
	else:
		_lines[3].text = sol.get("reason", "")
		_lines[3].add_theme_color_override("font_color", UiKit.WARN)
	_bar.size.x = 320.0 * sol.get("quality", 0.0)
	_bar.color = _quality_color(sol.get("quality", 0.0))


static func _quality_color(q: float) -> Color:
	return UiKit.GOOD if q >= 0.6 else (UiKit.WARN if q >= 0.35 else UiKit.BAD)


func _build_overlay(root: Control) -> void:
	var box := UiKit.bottom_panel(root)
	box.add_child(UiKit.label("TORPEDO DATA COMPUTER", 22, UiKit.BRASS))
	_lines.clear()
	for i in 4:
		var l := UiKit.label()
		box.add_child(l)
		_lines.append(l)
	var row := HBoxContainer.new()
	row.add_child(UiKit.label("SOLUTION QUALITY ", 16, UiKit.DIM))
	var meter := ColorRect.new()
	meter.color = Color(1, 1, 1, 0.08)
	meter.custom_minimum_size = Vector2(320, 18)
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(meter)
	_bar = ColorRect.new()
	_bar.size = Vector2(0, 18)
	meter.add_child(_bar)
	box.add_child(row)
	box.add_child(UiKit.label("[C] clear the marks    " + footer(cluster != ""), 14, UiKit.DIM))


func station_input(event: InputEvent) -> void:
	if key_pressed(event, KEY_W):
		order("speed", 1.0)
	elif key_pressed(event, KEY_S):
		order("speed", -1.0)
	elif key_pressed(event, KEY_A):
		order("course", -5.0)
	elif key_pressed(event, KEY_D):
		order("course", 5.0)
	elif key_pressed(event, KEY_C):
		order("clear")
	elif key_pressed(event, KEY_T):
		order("send")
