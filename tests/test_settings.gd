extends RefCounted
## Settings: saved and loaded back, bad values ignored, look sensitivity and invert Y.

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
