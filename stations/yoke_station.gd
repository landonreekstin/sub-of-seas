class_name YokeStation
extends Station
## The Typhoon's command bay (Blaney: a realistic control scheme, as in The Hunt for Red October):
## the helmsman and the planesman sit side by side facing the bow, each at an aircraft-style
## yoke. Built facing -Z (the bow), the seat behind the console.
## Helmsman (`role` "helm"): A/D or the mouse turns the yoke, the rudder following it (hold to
## turn harder), C centres it; W/S the engine order lever beside him.
## Planesman ("dive"): hold W to push the yoke forward and take her down, S to pull it back and
## bring her up (Shift: gently); she holds the depth where you let go. 1-4 the depth presets.

const DIVE_RATE := 4.0 ## m a second the ordered depth moves with the yoke right over
const MOUSE_STEP := 70.0 ## px of mouse movement for one step of rudder

var role := "helm"
var _yoke: Node3D
var _lever: Node3D
var _screen: Label3D
var _lines: Array[Label] = []
var _push := 0.0 ## the planesman's yoke, -1 pulled right back .. 1 pushed right forward
var _mouse := 0.0
var _sent := 0.0


func _ready() -> void:
	var steel := Color("#4A5560")
	Build.box(self, Vector3(0.48, 0.45, 0.48), Vector3(0, 0.225, 0.25), Color("#2E3A44")) # the seat
	Build.box(self, Vector3(0.48, 0.62, 0.08), Vector3(0, 0.76, 0.5), Color("#2E3A44"))
	Build.box(self, Vector3(0.44, 0.08, 0.42), Vector3(0, 0.49, 0.25), Color("#5A3A2E"), false) # brown leather
	Build.box(self, Vector3(0.95, 0.82, 0.5), Vector3(0, 0.41, -0.6), steel) # the console
	Build.box(self, Vector3(0.95, 0.62, 0.1), Vector3(0, 1.1, -0.82), steel)
	Build.box(self, Vector3(0.66, 0.34, 0.03), Vector3(0, 1.12, -0.765), Color("#0C1418"), false)
	_screen = Build.label(self, "", Vector3(0, 1.12, -0.745), 30, Color("#7CE0A8"))
	for k in 3: # dials along the console's top
		var x := -0.3 + k * 0.3
		Build.cyl(self, 0.08, 0.03, Vector3(x, 0.84, -0.5), Color("#151515"), Vector3.UP)
		Build.cyl(self, 0.085, 0.02, Vector3(x, 0.83, -0.5), SubInterior.BRASS, Vector3.UP)
	Build.sphere(self, 0.025, Vector3(-0.38, 0.84, -0.75), UiKit.GOOD, 2.0)
	Build.sphere(self, 0.025, Vector3(0.38, 0.84, -0.75), Color("#E8B04A"), 2.0)
	# The column out of the console and the yoke on it.
	Build.box(self, Vector3(0.07, 0.07, 0.34), Vector3(0, 0.74, -0.2), Color("#1E1E1E"), false)
	_yoke = Node3D.new()
	_yoke.position = Vector3(0, 0.74, -0.03)
	add_child(_yoke)
	Build.cyl(_yoke, 0.05, 0.06, Vector3.ZERO, Color("#1E1E1E"), Vector3.BACK)
	Build.box(_yoke, Vector3(0.36, 0.045, 0.045), Vector3.ZERO, Color("#1E1E1E"), false)
	for side in [-1.0, 1.0]:
		Build.box(_yoke, Vector3(0.05, 0.16, 0.05), Vector3(side * 0.18, 0.06, 0), Color("#1E1E1E"), false)
		Build.box(_yoke, Vector3(0.03, 0.03, 0.03), Vector3(side * 0.18, 0.15, 0), Color("#B23A2E"), false)
	if role == "helm": # the engine order lever, by his right hand
		Build.box(self, Vector3(0.14, 0.25, 0.3), Vector3(0.36, 0.86, -0.28), Color("#2E3A44"), false)
		_lever = Node3D.new()
		_lever.position = Vector3(0.36, 0.98, -0.28)
		add_child(_lever)
		Build.box(_lever, Vector3(0.025, 0.18, 0.025), Vector3(0, 0.09, 0), Color("#8A8F86"), false)
		Build.sphere(_lever, 0.03, Vector3(0, 0.19, 0), Color("#1E1E1E"))
	Build.hitbox(self, Vector3(0.95, 1.4, 1.35), Vector3(0, 0.7, -0.15))
	set_view(Vector3(0, 1.18, 0.22), Vector3(0, 0.92, -0.85))


func _process(delta: float) -> void:
	if Sim.world == null:
		return
	var sub := Sim.world.sub
	if role == "helm":
		_yoke.rotation.z = lerp_angle(_yoke.rotation.z, deg_to_rad(-sub.rudder * 25.0), minf(delta * 8.0, 1.0))
		_lever.rotation.x = deg_to_rad(-sub.telegraph * 15.0)
		sound_on_change("telegraph", sub.telegraph, "telegraph_ding", Vector3(0.36, 1.0, -0.28), -6.0)
		_screen.text = "КУРС %03d°\nCOURSE  %s" % [roundi(sub.heading) % 360, "%4.1f kn" % (sub.speed / SubState.KNOT)]
	else:
		var want := clampf((sub.ordered_depth - sub.depth) * 0.1, -1.0, 1.0)
		if overlay != null and not broken:
			want = _held()
			if want != 0.0:
				var to := clampf(sub.ordered_depth + want * DIVE_RATE * delta, 0.0, 200.0)
				sub.ordered_depth = to # shown at once, confirmed by the host
				_sent += delta
				if _sent >= 0.2:
					_sent = 0.0
					order("depth", to)
		_push = move_toward(_push, want, delta * 3.0)
		_yoke.position.z = -0.03 - _push * 0.09
		_yoke.rotation.x = -_push * 0.35
		_screen.text = "ГЛУБИНА %3d m\nDEPTH  ord %d" % [roundi(sub.depth), roundi(sub.ordered_depth)]
	sound_while("yoke", "wheel_loop", 0.5 if absf(_push) > 0.05 and role == "dive" else 0.0, Vector3(0, 0.8, -0.2), -8.0)
	if overlay != null:
		_update_lines(sub)


## The planesman's hold on the yoke: forward (W) dives, back (S) climbs.
func _held() -> float:
	var push := 0.0
	if Input.is_physical_key_pressed(KEY_W):
		push += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		push -= 1.0
	return push * (0.3 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)


func _update_lines(sub: SubState) -> void:
	if role == "helm":
		var side := "AMIDSHIPS" if sub.rudder == 0 else ("%s %d°" % ["RIGHT" if sub.rudder > 0 else "LEFT", absf(sub.rudder_angle())])
		_lines[0].text = "YOKE / RUDDER  %-15s [A/D] or mouse, hold to turn harder   [C] centre" % side
		_lines[1].text = "ENGINE ORDER   %-15s [W/S]" % SubState.TELEGRAPH_NAMES[sub.telegraph]
		_lines[2].text = "HEADING %03d°   SPEED %4.1f kn" % [roundi(sub.heading) % 360, sub.speed / SubState.KNOT]
	else:
		var under := Sim.world.seabed.floor_depth(sub.pos) - sub.depth
		_lines[0].text = "YOKE  hold [W] push forward: down    hold [S] pull back: up    [Shift] gently"
		_lines[1].text = "DEPTH %5.1f m   HOLDING %5.0f m   test %d   UNDER KEEL %s" % [sub.depth, sub.ordered_depth, sub.data.test_depth, "deep" if under > 300.0 else "%d m" % roundi(under)]
		_lines[2].text = "[1] surface  [2] periscope depth %d m  [3] 45 m  [4] test depth" % sub.data.periscope_depth
		_lines[1].add_theme_color_override("font_color", UiKit.BAD if sub.depth > sub.data.test_depth or under < 15.0 else UiKit.CREAM)


func _build_overlay(root: Control) -> void:
	var box := UiKit.bottom_panel(root)
	box.add_child(UiKit.label("HELMSMAN" if role == "helm" else "PLANESMAN", 22, UiKit.BRASS))
	_lines.clear()
	for i in 3:
		var l := UiKit.label()
		box.add_child(l)
		_lines.append(l)
	box.add_child(UiKit.label(footer(cluster != ""), 14, UiKit.DIM))


func station_input(event: InputEvent) -> void:
	var sub := Sim.world.sub
	if role == "dive":
		if event is InputEventKey and event.pressed and not event.echo:
			var key: Key = event.physical_keycode
			if DiveStation.PRESETS.has(key):
				var d: float = DiveStation.PRESETS[key]
				d = sub.data.periscope_depth if d == -1.0 else (float(sub.data.test_depth) if d == -2.0 else d)
				sub.ordered_depth = d
				order("depth", d)
			elif key == KEY_W or key == KEY_S:
				_sent = 1.0 # the first nudge goes at once
		elif event is InputEventKey and not event.pressed and (event.physical_keycode == KEY_W or event.physical_keycode == KEY_S):
			order("depth", sub.ordered_depth) # where you let go
		return
	if event is InputEventMouseMotion:
		_mouse += event.relative.x
		if absf(_mouse) < MOUSE_STEP:
			return
		sub.rudder = clampi(sub.rudder + int(signf(_mouse)), -3, 3)
		_mouse = 0.0
	elif key_pressed(event, KEY_A): # held, the key repeats and the yoke goes further over
		sub.rudder = maxi(sub.rudder - 1, -3)
	elif key_pressed(event, KEY_D):
		sub.rudder = mini(sub.rudder + 1, 3)
	elif key_pressed(event, KEY_C):
		sub.rudder = 0
	elif key_pressed(event, KEY_W):
		sub.telegraph = mini(sub.telegraph + 1, 4)
	elif key_pressed(event, KEY_S):
		sub.telegraph = maxi(sub.telegraph - 1, -2)
	else:
		return
	order("telegraph", sub.telegraph)
	order("rudder", sub.rudder)
