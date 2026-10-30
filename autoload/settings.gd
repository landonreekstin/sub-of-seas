class_name GameSettings
extends Node
## The player's settings (user://settings.cfg): audio volumes, graphics and controls. Loaded
## and applied at start, before Controls builds the input map; the settings menu
## (ui/settings_menu.gd) changes a value with set_value(), which applies and saves it.

const PATH := "user://settings.cfg"
## Sound buses under Master; every sound in the game plays on one of them.
const BUSES: Array[String] = ["Effects", "Music", "Voice"]
const WINDOW_MODES: Array[String] = ["Windowed", "Borderless fullscreen", "Fullscreen"]
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
## [name, 3D render scale, MSAA]
const QUALITIES := [["Low", 0.67, Viewport.MSAA_DISABLED], ["Medium", 0.85, Viewport.MSAA_2X], ["High", 1.0, Viewport.MSAA_4X]]
const FPS_CAPS: Array[int] = [0, 60, 120, 144]
const BASE_LOOK := 0.0025 ## radians per pixel at sensitivity 1
const DEFAULTS := {
	"master": 0.8, "effects": 1.0, "music": 0.6, "voice": 1.0,
	"window": 0, "resolution": 0, "vsync": true, "quality": 2, "fps_cap": 0, "fov": 75.0,
	"sensitivity": 1.0, "invert_y": false,
}

signal changed(key: String) ## after set_value; the player's camera and the periscope listen

var values := {}
## action -> physical keycode, only for keys the player changed from Controls.BINDINGS
var keys := {}
var path := PATH


func _ready() -> void:
	load_file()
	for k: String in values:
		if k not in ["window", "resolution"] or values[k] != DEFAULTS[k]: # leave a default window alone
			apply(k)


func load_file() -> void:
	values = DEFAULTS.duplicate()
	keys.clear()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for k: String in DEFAULTS:
		var v: Variant = cfg.get_value("settings", k, DEFAULTS[k])
		if typeof(v) == typeof(DEFAULTS[k]) or (DEFAULTS[k] is float and v is int):
			values[k] = v
	for action: String in cfg.get_section_keys("keys") if cfg.has_section("keys") else PackedStringArray():
		keys[action] = int(cfg.get_value("keys", action))


func save_file() -> void:
	var cfg := ConfigFile.new()
	for k: String in values:
		cfg.set_value("settings", k, values[k])
	for action: String in keys:
		cfg.set_value("keys", action, keys[action])
	cfg.save(path)


func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	values[key] = value
	apply(key)
	save_file()
	changed.emit(key)


func apply(key: String) -> void:
	match key:
		"master":
			_set_volume(0, values.master)
		"effects", "music", "voice":
			_set_volume(_bus(key.capitalize()), values[key])
		"window", "resolution":
			_apply_window()
		"vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
		"quality":
			apply_quality(get_viewport())
		"fps_cap":
			Engine.max_fps = FPS_CAPS[clampi(values.fps_cap, 0, FPS_CAPS.size() - 1)]


## Render scale and MSAA for a viewport (the main one, and the periscope's).
func apply_quality(vp: Viewport) -> void:
	if vp == null:
		return
	var q: Array = QUALITIES[clampi(values.quality, 0, QUALITIES.size() - 1)]
	vp.scaling_3d_scale = q[1]
	vp.msaa_3d = q[2]


## Mouse look in radians per pixel, signed for invert Y on the vertical axis.
func look(vertical := false) -> float:
	var s: float = BASE_LOOK * float(values.sensitivity)
	return -s if vertical and values.invert_y else s


## The key for an action: the player's own, or the default.
func key_for(action: String) -> Key:
	if keys.has(action):
		return keys[action] as Key
	var defaults: Array = Controls.BINDINGS.get(action, [])
	return defaults[0] if not defaults.is_empty() else KEY_NONE


func set_key(action: String, key: Key) -> void:
	var defaults: Array = Controls.BINDINGS.get(action, [])
	if not defaults.is_empty() and defaults[0] == key:
		keys.erase(action)
	else:
		keys[action] = key
	Controls.bind(action)
	save_file()


func reset_keys() -> void:
	keys.clear()
	for action: String in Controls.BINDINGS:
		Controls.bind(action)
	save_file()


func _bus(bus_name: String) -> int:
	var i := AudioServer.get_bus_index(bus_name)
	if i == -1:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")
	return i


func _set_volume(bus: int, linear: float) -> void:
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(bus, linear <= 0.0)


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	match int(values.window):
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var size := RESOLUTIONS[clampi(values.resolution, 0, RESOLUTIONS.size() - 1)]
			var screen := DisplayServer.screen_get_usable_rect()
			size = Vector2i(mini(size.x, screen.size.x), mini(size.y, screen.size.y))
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)
