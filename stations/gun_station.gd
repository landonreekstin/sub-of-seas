class_name GunStation
extends Station
## The deck gun (lando: "a gun on the casing for fighting on the surface, crewed from inside, up
## the conning-tower hatch"). Inside it is the ladder up to the bridge hatch; manned, the view
## is the gunlayer's out on the casing. Surfaced only: the hatch is shut below, and diving
## sends the gun crew tumbling down it.
## Mouse trains the gun, W/S (Shift: fine) or the wheel set the range on the sight, F takes a
## rangefinder reading on the ship in the sight, Z the telescope, LMB or Space fires. Watch
## where the rounds fall and walk them onto her: a round that goes over can still hit a tall
## ship on its way down, one that falls short never does.

const ARC := 150.0 ## degrees either side of the bow it can train before the fairwater's in the way
const TRAIN_SENSITIVITY := 0.08
const WIDE_FOV := 45.0
const SIGHT_FOV := 12.0

var overhead := 2.3 ## height of the deckhead the hatch is in, above this station's floor
var bearing := 0.0 ## relative to the bow
var range_m := 1500.0
var zoom := false
var _view_rect: TextureRect
var _sight: Label
var _status: Label
var _ammo: Label
var _reading: Label
var _reading_timer := 0.0


func _ready() -> void:
	# The ladder up to the bridge hatch, and the hatch ring in the deckhead.
	for side in [-0.22, 0.22]:
		Build.cyl(self, 0.03, overhead, Vector3(side, overhead * 0.5, 0), Color("#8A8F86"))
	for i in int(overhead / 0.33):
		Build.cyl(self, 0.02, 0.44, Vector3(0, 0.3 + i * 0.33, 0), Color("#8A8F86"), Vector3.RIGHT)
	Build.cyl(self, 0.42, 0.12, Vector3(0, overhead - 0.06, -0.1), Color("#3A3F38"))
	Build.cyl(self, 0.34, 0.14, Vector3(0, overhead - 0.06, -0.1), Color("#1A1C1A"))
	var dog := Build.box(self, Vector3(0.5, 0.04, 0.06), Vector3(0, overhead - 0.16, -0.1), Color("#B23A2E"), false) # the hatch's dogging wheel bar
	dog.rotation.y = 0.6
	Build.label(self, "DECK GUN ↑", Vector3(0, 1.95, 0.12), 34, UiKit.BRASS)
	Build.hitbox(self, Vector3(0.7, 1.9, 0.35), Vector3(0, 0.95, 0))
	# Look up at the hatch itself to climb out on deck (Blaney: walk on top of the boat).
	var hatch := BridgeHatch.new()
	hatch.position = Vector3(0, overhead - 0.06, -0.1)
	add_child(hatch)
	Build.area(hatch, Vector3(0.9, 0.25, 0.9), Vector3.ZERO)
	set_view(Vector3(0, 1.6, 0.8), Vector3(0, overhead, -0.1))


func get_prompt(player: Player) -> String:
	if not broken and not Sim.world.sub.is_surfaced():
		return "%s — the bridge hatch is shut: surface first" % display_name
	return super.get_prompt(player)


func _process(delta: float) -> void:
	if overlay == null or Sim.world == null:
		return
	var ext := Game.instance.exterior
	ext.gun_bearing = bearing
	ext.gun_range = range_m
	ext.gun_fov = SIGHT_FOV if zoom else WIDE_FOV
	var sub := Sim.world.sub
	var gun: Dictionary = Game.instance.crew.get("gun", {})
	var true_brg := fposmod(sub.heading + bearing, 360.0)
	_sight.text = "RANGE %d m\nBRG %03d°  REL %s%03d°" % [roundi(range_m), roundi(true_brg) % 360, "-" if bearing < 0 else "+", absi(roundi(bearing))]
	var ready := int(gun.get("ready", 0))
	var wait := float(gun.get("next", 0.0)) - Sim.world.time
	if ready <= 0:
		_status.text = "NO ROUND AT THE GUN — someone has to pass ammunition up (ammo scuttle)"
		_status.add_theme_color_override("font_color", UiKit.WARN)
	elif wait > 0.0:
		_status.text = "LOADING ..."
		_status.add_theme_color_override("font_color", UiKit.DIM)
	else:
		_status.text = "READY — [LMB / Space] fire"
		_status.add_theme_color_override("font_color", UiKit.GOOD)
	_ammo.text = "%s   ready-use %d / %d   magazine %d" % [sub.data.gun_name, ready, sub.data.gun_ready, int(gun.get("magazine", 0))]
	_reading_timer -= delta
	if _reading_timer <= 0.0:
		_reading.text = ""


func _build_overlay(root: Control) -> void:
	var ext := Game.instance.exterior
	var view := TextureRect.new()
	view.texture = ext.viewport.get_texture()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(view)
	_view_rect = view
	# The gunsight: a ring and a cross, the range set on it.
	var sight := Control.new()
	sight.set_anchors_preset(Control.PRESET_FULL_RECT)
	sight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sight.draw.connect(func() -> void:
		var c := sight.size * 0.5
		var ink := Color(0.05, 0.05, 0.05, 0.85)
		sight.draw_arc(c, 34.0, 0.0, TAU, 48, ink, 2.0)
		for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			sight.draw_line(c + d * 12.0, c + d * 60.0, ink, 2.0)
		sight.draw_circle(c, 2.0, ink))
	root.add_child(sight)
	var top := UiKit.panel()
	root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 12
	_sight = UiKit.label("", 20)
	_sight.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_sight)
	_reading = UiKit.label("", 22, UiKit.WARN)
	root.add_child(_reading)
	_reading.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_reading.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_reading.offset_top = 70
	var box := UiKit.bottom_panel(root)
	_status = UiKit.label()
	box.add_child(_status)
	_ammo = UiKit.label("", 16)
	box.add_child(_ammo)
	box.add_child(UiKit.label("[mouse] train   [W/S] range ±100 m (Shift ±25)   [wheel] ±50 m   [F] rangefinder   [Z] telescope", 14, UiKit.DIM))
	box.add_child(UiKit.label(footer(cluster != "") + "    (diving clears the deck)", 14, UiKit.DIM))
	ext.eye_mode = "gun"
	ext.set_active(true)


func on_leave() -> void:
	var ext := Game.instance.exterior
	ext.eye_mode = "scope"
	ext.set_active(false)
	super.on_leave()


func station_input(event: InputEvent) -> void:
	var fine := Input.is_physical_key_pressed(KEY_SHIFT)
	if event is InputEventMouseMotion:
		var sens := TRAIN_SENSITIVITY * float(Settings.get_value("sensitivity")) * (0.3 if zoom else 1.0)
		bearing = clampf(bearing + event.relative.x * sens, -ARC, ARC)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_fire()
			MOUSE_BUTTON_WHEEL_UP:
				_set_range(range_m + 50.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				_set_range(range_m - 50.0)
	elif key_pressed(event, KEY_SPACE):
		_fire()
	elif key_pressed(event, KEY_W):
		_set_range(range_m + (25.0 if fine else 100.0))
	elif key_pressed(event, KEY_S):
		_set_range(range_m - (25.0 if fine else 100.0))
	elif key_pressed(event, KEY_Z):
		zoom = not zoom
		click(0.0, 0.8)
	elif key_pressed(event, KEY_F):
		_rangefinder()


func _set_range(r: float) -> void:
	var was := range_m
	range_m = clampf(r, 200.0, Sim.world.sub.data.gun_range)
	if range_m != was:
		click(-6.0, 1.2)


func _fire() -> void:
	var gun: Dictionary = Game.instance.crew.get("gun", {})
	if int(gun.get("ready", 0)) <= 0 or Sim.world.time < float(gun.get("next", 0.0)):
		click(-4.0, 0.6) # the trigger, and nothing
		return
	order("fire", [fposmod(Sim.world.sub.heading + bearing, 360.0), range_m])


## A rangefinder reading on the ship nearest the line of sight, with the operator's error; it
## goes straight onto the sight.
func _rangefinder() -> void:
	_reading_timer = 3.0
	var sub := Sim.world.sub
	var true_brg := fposmod(sub.heading + bearing, 360.0)
	var best: ShipState = null
	var best_off := 1.5 if zoom else 3.0
	for ship in Sim.world.ships:
		var to := ship.pos - sub.pos
		var off := absf(wrapf(rad_to_deg(atan2(to.x, to.y)) - true_brg, -180.0, 180.0))
		if off < best_off and to.length() < sub.data.gun_range * 1.5 and not ship.is_sinking():
			best_off = off
			best = ship
	if best == null:
		_reading.text = "nothing in the sight"
		return
	var d := best.pos.distance_to(sub.pos) * (1.0 + randf_range(-0.04, 0.04) * (0.5 if zoom else 1.0))
	_set_range(snappedf(d, 25.0))
	_reading.text = "RANGEFINDER: %d m" % roundi(range_m)
	click(0.0, 1.3)


## The bridge hatch in the deckhead over the gun's ladder: up it onto the deck (Deck).
class BridgeHatch extends Node3D:
	func get_prompt(_player: Player) -> String:
		if not Deck.can_go_out():
			return "Bridge hatch — shut while she's dived"
		return "[E] Climb out on deck"

	func interact(player: Player) -> void:
		if Deck.can_go_out():
			player.go_on_deck()
