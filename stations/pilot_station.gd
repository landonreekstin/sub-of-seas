class_name PilotStation
extends Station
## The Titan's pilot (Blaney: controlled with a game controller, like the real one): he sits on
## the floor at the after end with the controller in his hands, the screen on the wall ahead.
## He does it all: the thrusters ahead and astern, turning, up and down, and dropping the
## weights to go up in a hurry.
## Keyboard: W/S thrust, A/D turn, hold R rise / F sink (Shift: gently), X twice drops the weights.
## A game controller, if one is plugged in: left stick thrust and turn, right trigger sink, left
## trigger rise, B twice drops the weights.

const DIVE_RATE := 25.0 ## m a second the ordered depth moves, held right over
const STICK_DEAD := 0.2

var seated := true ## a bot here sits on the floor with the controller (BotView)
var _pad: Node3D
var _screen: Label3D
var _lines: Array[Label] = []
var _sent := 0.0
var _confirm_until := 0.0
var _last_stick := Vector2i(99, 99)


func _ready() -> void:
	# The controller in his hands: a dark body, two grips, two sticks and the coloured buttons.
	_pad = Node3D.new()
	_pad.position = Vector3(0, 0.62, -0.32)
	_pad.rotation.x = -0.5
	add_child(_pad)
	var grey := Color("#2A2C2E")
	Build.box(_pad, Vector3(0.16, 0.035, 0.08), Vector3.ZERO, grey, false)
	for side in [-1.0, 1.0]:
		var grip := Build.box(_pad, Vector3(0.045, 0.035, 0.08), Vector3(side * 0.07, -0.005, 0.045), grey, false)
		grip.rotation.y = side * 0.35
		Build.cyl(_pad, 0.012, 0.015, Vector3(side * 0.035, 0.022, side * -0.005), Color("#151515"), Vector3.UP)
	for k in 4:
		var col: Color = [Color("#3FA34D"), Color("#B23A2E"), Color("#2E6FB2"), Color("#E0B020")][k]
		Build.sphere(_pad, 0.007, Vector3(0.055 + [0.0, 0.012, -0.012, 0.0][k], 0.02, [0.012, 0.0, 0.0, -0.012][k] - 0.01), col, 1.0)
	# The screen on the wall ahead to starboard.
	var mount := Node3D.new()
	mount.position = Vector3(0.62, 1.15, -1.1)
	mount.rotation.y = 0.5
	add_child(mount)
	Build.box(mount, Vector3(0.62, 0.4, 0.04), Vector3.ZERO, Color("#151719"), false)
	Build.box(mount, Vector3(0.56, 0.34, 0.01), Vector3(0, 0, 0.022), Color("#0A1420"), false)
	_screen = Build.label(mount, "", Vector3(0, 0, 0.03), 18, Color("#7CE0F0"))
	Build.hitbox(self, Vector3(0.8, 1.0, 0.8), Vector3(0, 0.5, 0))
	set_view(Vector3(0, 1.05, 0.0), Vector3(0.15, 0.9, -1.2))
	bot_arms = Vector2(0.9, 0.9) # the controller held in front of him


func _process(delta: float) -> void:
	if Sim.world == null:
		return
	var sub := Sim.world.sub
	var strain := Sim.world.hull_strain
	_screen.text = "DEPTH %5d m   HOLD %5d m\nSPEED %3.1f kn   HDG %03d°\nBATTERY %3d%%   UNDER %s\nHULL MONITOR  %s" % [
		roundi(sub.depth), roundi(sub.ordered_depth), sub.speed / SubState.KNOT, roundi(sub.heading) % 360,
		roundi(sub.battery * 100.0), _under(sub), "OK" if strain < 0.05 else "STRAIN %d%%" % roundi(strain * 100.0)]
	_screen.modulate = Color("#FF6A5A") if strain > 0.5 else Color.WHITE
	_pad.rotation.z = lerp_angle(_pad.rotation.z, deg_to_rad(-sub.rudder * 8.0), minf(delta * 8.0, 1.0))
	if overlay == null or broken:
		return
	var updown := _updown()
	if updown != 0.0:
		var to := clampf(sub.ordered_depth + updown * DIVE_RATE * delta, 0.0, sub.data.crush_depth)
		sub.ordered_depth = to
		_sent += delta
		if _sent >= 0.2:
			_sent = 0.0
			order("depth", to)
	_stick()
	_update_lines(sub)


func _under(sub: SubState) -> String:
	var under := Sim.world.seabed.floor_depth(sub.pos) - sub.depth
	return "deep" if under > 400.0 else "%d m" % roundi(under)


## Down (+) or up (-), from R/F or the triggers.
func _updown() -> float:
	var v := 0.0
	if Input.is_physical_key_pressed(KEY_F):
		v += 1.0
	if Input.is_physical_key_pressed(KEY_R):
		v -= 1.0
	if not Input.get_connected_joypads().is_empty():
		v += Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	return clampf(v, -1.0, 1.0) * (0.25 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)


## The left stick, if a controller is in: thrust and turn straight from it.
func _stick() -> void:
	if Input.get_connected_joypads().is_empty():
		return
	var x := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var y := -Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	var want := Vector2i(
		0 if absf(x) < STICK_DEAD else roundi(x * 3.0),
		0 if absf(y) < STICK_DEAD else clampi(roundi(y * 4.0), -2, 4))
	if want == _last_stick:
		return
	_last_stick = want
	var sub := Sim.world.sub
	sub.rudder = want.x
	sub.telegraph = want.y
	order("telegraph", sub.telegraph)
	order("rudder", sub.rudder)


func _update_lines(sub: SubState) -> void:
	var side := "STRAIGHT" if sub.rudder == 0 else ("%s %d" % ["RIGHT" if sub.rudder > 0 else "LEFT", absi(sub.rudder)])
	_lines[0].text = "THRUST %-12s [W/S]   TURN %-9s [A/D]   %s" % [SubState.TELEGRAPH_NAMES[sub.telegraph], side, "controller: left stick" if not Input.get_connected_joypads().is_empty() else "no controller: keyboard"]
	_lines[1].text = "DEPTH %6.1f m   HOLDING %5.0f m   hold [R] up  [F] down  [Shift] gently   (triggers)" % [sub.depth, sub.ordered_depth]
	_lines[2].text = "[X] twice: DROP THE WEIGHTS and go up   (B)   rated %d m" % sub.data.test_depth
	_lines[1].add_theme_color_override("font_color", UiKit.BAD if sub.depth > sub.data.test_depth else UiKit.CREAM)


func _build_overlay(root: Control) -> void:
	var box := UiKit.bottom_panel(root)
	box.add_child(UiKit.label("PILOT", 22, UiKit.BRASS))
	_lines.clear()
	for i in 3:
		var l := UiKit.label()
		box.add_child(l)
		_lines.append(l)
	box.add_child(UiKit.label(footer(cluster != ""), 14, UiKit.DIM))


func station_input(event: InputEvent) -> void:
	var sub := Sim.world.sub
	var drop: bool = key_pressed(event, KEY_X) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
	if drop:
		var now := Time.get_ticks_msec() / 1000.0
		if now < _confirm_until:
			order("weights")
			_confirm_until = 0.0
		else:
			_confirm_until = now + 2.0
			Game.instance.hud.show_message("Drop the weights? Press again to let them go.", 2.0)
		return
	if key_pressed(event, KEY_A):
		sub.rudder = maxi(sub.rudder - 1, -3)
	elif key_pressed(event, KEY_D):
		sub.rudder = mini(sub.rudder + 1, 3)
	elif key_pressed(event, KEY_W):
		sub.telegraph = mini(sub.telegraph + 1, 4)
	elif key_pressed(event, KEY_S):
		sub.telegraph = maxi(sub.telegraph - 1, -2)
	elif event is InputEventKey and not event.pressed and (event.physical_keycode == KEY_R or event.physical_keycode == KEY_F):
		order("depth", sub.ordered_depth) # where you let go
		return
	else:
		return
	order("telegraph", sub.telegraph)
	order("rudder", sub.rudder)
