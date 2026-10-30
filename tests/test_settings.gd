extends RefCounted
## Settings: saved and loaded back, bad values ignored, look sensitivity and invert Y; the
## walking controls; the mesh builders.

var runner: Object


func _fresh(path: String) -> GameSettings:
	var s := GameSettings.new()
	s.path = path
	return s


func test_settings_round_trip() -> bool:
	var path := "user://test_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var a := _fresh(path)
	a.load_file()
	runner.check(a.values == GameSettings.DEFAULTS, "no file: defaults")
	a.values.effects = 0.25
	a.values.fov = 90.0
	a.values.invert_y = true
	a.keys["jump"] = KEY_J
	a.save_file()
	var b := _fresh(path)
	b.load_file()
	runner.check(is_equal_approx(b.values.effects, 0.25) and b.values.fov == 90.0 and b.values.invert_y, "values come back")
	runner.check(b.keys.get("jump") == KEY_J, "a rebound key comes back")
	runner.check(b.look(true) < 0.0 and b.look() > 0.0, "invert Y flips only the vertical look")
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "fov", "wide")
	cfg.save(path)
	b.load_file()
	runner.check(b.values.fov == GameSettings.DEFAULTS.fov, "a value of the wrong type falls back to the default")
	a.free()
	b.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return true


func test_built_meshes_are_closed_and_sized() -> bool:
	var m := Build.bevel_box_mesh(Vector3(2.0, 0.5, 1.0))
	var aabb := m.get_aabb()
	runner.check(aabb.size.is_equal_approx(Vector3(2.0, 0.5, 1.0)), "a bevelled box is the size asked for")
	runner.check(m.surface_get_array_len(0) == (6 * 2 + 12 * 2 + 8) * 3, "6 faces, 12 edge bevels and 8 corners")
	runner.check(Build.bevel_box_mesh(Vector3(2.0, 0.5, 1.0)) == m, "the same size shares one mesh")
	var l := Build.lathe_mesh([Vector2(0, 0), Vector2(1, 0), Vector2(1, 2), Vector2(0, 2)], 8)
	runner.check(l.get_aabb().size.is_equal_approx(Vector3(2.0, 2.0, 2.0)), "a lathed cylinder spans its radius and height")
	var ship := ShipModels.build(load("res://data/ships/destroyer.tres"))
	var box := AABB()
	for c in ship.get_children():
		if c is MeshInstance3D:
			box = box.merge((c as MeshInstance3D).get_aabb() * (c as MeshInstance3D).transform) if box.size != Vector3.ZERO else (c as MeshInstance3D).get_aabb() * (c as MeshInstance3D).transform
	var d: ShipClassData = load("res://data/ships/destroyer.tres")
	runner.check(absf(box.size.z - d.length) < d.length * 0.06, "the destroyer's hull is its length")
	runner.check(box.position.y < -3.0, "the hull goes down below the waterline")
	ship.free()
	return true
