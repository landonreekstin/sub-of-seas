class_name PeriscopeStation
extends Station
## Attack periscope in the conning tower. Mouse trains it, Z switches power, R raises or
## lowers, F takes a stadimeter range on whatever is under the crosshair, M marks it for the
## TDC (bearing and range).

const LOW_FOV := 32.0
const HIGH_FOV := 8.0
const TRAIN_SENSITIVITY := 0.08

var bearing := 0.0 ## relative to the bow, degrees
var high_power := false
var _eyepiece: Node3D
var _view_rect: TextureRect
var _status: Label
var _bearing_label: Label
var _range_label: Label
var _range_timer := 0.0


func _ready() -> void:
	Build.cyl(self, 0.11, 2.4, Vector3(0, 1.2, 0), Color("#6E756C"))
	_eyepiece = Node3D.new()
	add_child(_eyepiece)
	Build.box(_eyepiece, Vector3(0.36, 0.34, 0.3), Vector3(0, 0, 0), Color("#3A3F38"), false)
	Build.box(_eyepiece, Vector3(0.2, 0.1, 0.08), Vector3(0, 0.03, 0.18), Color("#151515"), false)
	Build.box(_eyepiece, Vector3(0.5, 0.06, 0.06), Vector3(0, -0.2, 0.05), Color("#C9A04A"), false) # handles
	Build.hitbox(self, Vector3(0.7, 2.0, 0.7), Vector3(0, 1.0, 0))
	set_view(Vector3(0, 1.6, 0.45), Vector3(0, 1.55, 0))


func _process(delta: float) -> void:
	if Sim.world == null:
		return
	var sub := Sim.world.sub
	var target_y := 1.6 if sub.periscope_raised else 0.55
	_eyepiece.position.y = move_toward(_eyepiece.position.y, target_y, delta * 1.2)
	if overlay == null:
		return
	var ext := Game.instance.exterior
	ext.scope_bearing = bearing
	ext.scope_fov = HIGH_FOV if high_power else LOW_FOV
	var height := sub.scope_height()
	_view_rect.visible = height > 0.0
	if not sub.periscope_raised and not sub.is_surfaced():
		_status.text = "SCOPE DOWN — [R] raise"
	elif height <= 0.0:
		_status.text = "SCOPE UNDER WATER — depth %.0f m, periscope depth %d m" % [sub.depth, sub.data.periscope_depth]
	else:
		_status.text = "BRIDGE (surfaced)" if sub.is_surfaced() else "SCOPE UP — %s POWER" % ("HIGH" if high_power else "LOW")
	var true_brg := fposmod(sub.heading + bearing, 360.0)
	_bearing_label.text = "BRG %03d°   REL %s%03d°" % [roundi(true_brg) % 360, "-" if bearing < 0 else "+", absi(roundi(bearing))]
	_range_timer -= delta
	if _range_timer <= 0.0:
		_range_label.text = ""


func _build_overlay(root: Control) -> void:
	var ext := Game.instance.exterior
	var bg := ColorRect.new()
	bg.color = Color("#0B1A26")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	_view_rect = TextureRect.new()
	_view_rect.texture = ext.viewport.get_texture()
	_view_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view_rect.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(_view_rect)
	var lens := ColorRect.new()
	lens.set_anchors_preset(Control.PRESET_FULL_RECT)
	lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://ui/periscope_lens.gdshader")
	lens.material = sm
	root.add_child(lens)

	_bearing_label = UiKit.label("", 22)
	root.add_child(_bearing_label)
	_bearing_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_bearing_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bearing_label.offset_top = 16
	_range_label = UiKit.label("", 22, UiKit.WARN)
	root.add_child(_range_label)
	_range_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_range_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_range_label.offset_top = 40
	_range_label.offset_left = 30

	var box := UiKit.bottom_panel(root)
	_status = UiKit.label()
	box.add_child(_status)
	box.add_child(UiKit.label("[mouse] train   [Z] power   [R] raise/lower   [F] stadimeter range   [M] mark for the TDC", 14, UiKit.DIM))
	box.add_child(UiKit.label(footer(cluster != ""), 14, UiKit.DIM))
	ext.set_active(true)


func on_leave() -> void:
	Game.instance.exterior.set_active(false)
	super.on_leave()


func station_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var sens := TRAIN_SENSITIVITY * (0.25 if high_power else 1.0)
		bearing = wrapf(bearing + event.relative.x * sens, -180.0, 180.0)
	elif key_pressed(event, KEY_Z):
		high_power = not high_power
	elif key_pressed(event, KEY_R):
		order("raised", not Sim.world.sub.periscope_raised)
	elif key_pressed(event, KEY_F):
		_take_range()
	elif key_pressed(event, KEY_M):
		_mark()


## The ship nearest the crosshair, or null.
func _on_the_wire() -> ShipState:
	var sub := Sim.world.sub
	var true_brg := fposmod(sub.heading + bearing, 360.0)
	var best: ShipState = null
	var best_off := 2.5 if not high_power else 1.0
	for ship in Sim.world.ships:
		var to := ship.pos - sub.pos
		var brg := rad_to_deg(atan2(to.x, to.y))
		var off := absf(wrapf(brg - true_brg, -180.0, 180.0))
		if off < best_off and to.length() < 9000.0:
			best_off = off
			best = ship
	return best


## Stadimeter range on `ship`, with an observer's error (smaller in high power).
func _stadimeter(ship: ShipState) -> float:
	var err := randf_range(-0.03, 0.03) * (0.5 if high_power else 1.0)
	return ship.pos.distance_to(Sim.world.sub.pos) * (1.0 + err)


## Mark: bearing and range to the TDC.
func _mark() -> void:
	_range_timer = 4.0
	var sub := Sim.world.sub
	var best := _on_the_wire() if sub.scope_height() > 0.0 else null
	if best == null:
		_range_label.text = "no target on the wire" if sub.scope_height() > 0.0 else ""
		return
	var rng := _stadimeter(best)
	var true_brg := fposmod(sub.heading + bearing + randf_range(-0.5, 0.5), 360.0)
	order("mark", [best.id, true_brg, rng])
	_range_label.text = "MARK — BRG %03d  RANGE %d m" % [roundi(true_brg) % 360, roundi(rng / 50.0) * 50]


## Stadimeter: range to the ship nearest the crosshair, with an observer's error.
func _take_range() -> void:
	_range_timer = 4.0
	var sub := Sim.world.sub
	if sub.scope_height() <= 0.0:
		_range_label.text = ""
		return
	var best := _on_the_wire()
	if best == null:
		_range_label.text = "no target on the wire"
		return
	order("ranged", true)
	var dist := _stadimeter(best)
	var aob := wrapf(rad_to_deg(atan2(-(best.pos - sub.pos).x, -(best.pos - sub.pos).y)) - best.heading, -180.0, 180.0)
	_range_label.text = "RANGE %d m   AoB %s %d°" % [roundi(dist / 50.0) * 50, "STBD" if aob > 0 else "PORT", absi(roundi(aob / 5.0) * 5)]
