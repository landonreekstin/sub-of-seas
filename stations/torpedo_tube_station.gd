class_name TorpedoTubeStation
extends Station
## One torpedo tube's breech. The firing drill is real enough to need a crew:
## reload (door shut, tube drained, someone working it) → flood → open outer door → fire.

var tube_index := 0
var stern := false ## in the after torpedo room, firing astern
var _lamp: MeshInstance3D
var _lines: Array[Label] = []


func _ready() -> void:
	# Faces +Z (aft), mounted on the forward bulkhead.
	Build.cyl(self, 0.3, 0.7, Vector3(0, 0, 0.35), Color("#8A8F86"), Vector3.BACK)
	Build.cyl(self, 0.31, 0.08, Vector3(0, 0, 0.72), Color("#C9A04A"), Vector3.BACK)
	Build.box(self, Vector3(0.3, 0.05, 0.05), Vector3(0, 0, 0.78), Color("#B23A2E"), false) # breech lever
	Build.label(self, str(tube_index + 1), Vector3(-0.22, 0.22, 0.77), 64)
	_lamp = Build.sphere(self, 0.05, Vector3(0.24, 0.22, 0.75), Color.RED, 2.0)
	Build.hitbox(self, Vector3(0.65, 0.65, 0.8), Vector3(0, 0, 0.4))
	set_view(Vector3(0, 0.15, 2.3), Vector3(0, 0, 0.6))


func _tube() -> Dictionary:
	return Game.instance.crew.tubes[tube_index]


func _process(_delta: float) -> void:
	var t := _tube()
	if sound_on_change("flooded", t.flooded, "lever") and t.flooded:
		Sfx.play_at(self, "flood", Vector3(0, 1.0, 0))
	sound_on_change("door", t.door, "clang")
	if sound_on_change("reloading", t.reload > 0.0, "lever") and t.reload > 0.0:
		Sfx.play_at(self, "reload", Vector3(0, 1.0, 0))
	sound_on_change("gyro", t.gyro, "click")
	var ready: bool = t.loaded and t.flooded and t.door
	_lamp.material_override = Build.mat(Color.GREEN if ready else (Color.ORANGE if t.loaded else Color.RED), 0.8)
	if overlay == null:
		return
	_lines[0].text = "LOADED %-4s  TUBE %-8s  OUTER DOOR %-6s  RESERVE %d" % [
		"YES" if t.loaded else "NO", "FLOODED" if t.flooded else "DRY", "OPEN" if t.door else "SHUT",
		Game.instance.crew.reserve]
	var follow: bool = Game.instance.crew.tdc.follow
	_lines[1].text = "GYRO ANGLE  %+d°   %s" % [t.gyro, "FOLLOWING THE TDC  ([A/D] takes it to manual)" if follow else "[A/D] ±1   [Shift] ±5"]
	_lines[1].add_theme_color_override("font_color", UiKit.GOOD if follow else UiKit.CREAM)
	var status := ""
	if ready:
		status = "READY — [SPACE] FIRE"
	elif t.reload > 0.0:
		status = "RELOADING %d%% — stay on the tube" % roundi(t.reload * 100.0)
	elif not t.loaded:
		status = "EMPTY — shut door, drain, then [L] reload" if (t.door or t.flooded) else "EMPTY — [L] reload"
	elif not t.flooded:
		status = "[F] flood tube"
	else:
		status = "[O] open outer door"
	_lines[2].text = status
	_lines[2].add_theme_color_override("font_color", UiKit.GOOD if ready else UiKit.WARN)


func _build_overlay(root: Control) -> void:
	var box := UiKit.bottom_panel(root)
	box.add_child(UiKit.label("TUBE %d — %s TORPEDO ROOM" % [tube_index + 1, "AFTER" if stern else "FORWARD"], 22, UiKit.BRASS))
	_lines.clear()
	for i in 3:
		var l := UiKit.label()
		box.add_child(l)
		_lines.append(l)
	box.add_child(UiKit.label("[L] reload  [F] flood/drain  [O] outer door  [SPACE] fire", 14, UiKit.DIM))
	box.add_child(UiKit.label(footer(cluster != ""), 14, UiKit.DIM))


func station_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var t := _tube()
	var step := 5 if event.shift_pressed else 1
	match event.physical_keycode:
		KEY_A:
			order("gyro", t.gyro - step)
		KEY_D:
			order("gyro", t.gyro + step)
		KEY_L:
			order("load")
		KEY_F:
			order("flood")
		KEY_O:
			order("door")
		KEY_SPACE:
			order("fire")
