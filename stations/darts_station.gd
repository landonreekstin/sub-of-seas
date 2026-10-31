class_name DartsStation
extends Station
## The rec room's dartboard, for whimsy between attacks (lando: a rec room with mini games).
## Walk up to the board, aim with the mouse while your hand sways, LMB (or Space) throws. Three darts a
## turn; the crew's best turns go up on the chalkboard (crew state, so everyone sees them).

const BOARD_R := 0.225 ## the board's radius, m (a real one scored to 0.17)
const SCALE := BOARD_R / 0.2255 ## real dartboard rings, in metres, scaled to this board
const ORDER := [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]
const OCHE := 2.37 ## m from the board

var _board: Node3D
var _aim := Vector2.ZERO ## metres from the bull, on the board's face
var _darts: Array[Vector2] = []
var _turn := 0
var _lines: Array[Label] = []
var _reticle: MeshInstance3D
var _stuck: Array[Node3D] = []
var _chalk: Label3D


func _ready() -> void:
	# The board hangs on the bulkhead at bull height 1.73 m; the station's origin is on the oche,
	# facing it along -Z.
	_board = Node3D.new()
	_board.position = Vector3(0, 1.73, -OCHE)
	add_child(_board)
	Build.cyl(_board, BOARD_R + 0.06, 0.04, Vector3(0, 0, -0.02), Color("#2B2B26"), Vector3.BACK)
	# Discs from the outside in, each a hair in front: double ring, singles, treble ring,
	# inner singles, outer bull, bull.
	var rings := [[0.17, Color("#C93A2E")], [0.162, Color("#1E1E20")], [0.107, Color("#2B7A3A")], [0.099, Color("#E8DFC4")], [0.0318, Color("#2B7A3A")], [0.0127, Color("#C93A2E")]]
	for i in rings.size():
		Build.cyl(_board, float(rings[i][0]) * SCALE, 0.01, Vector3(0, 0, 0.005 + 0.0015 * i), rings[i][1], Vector3.BACK)
	for i in 20:
		var a := deg_to_rad(90.0 - i * 18.0)
		var l := Build.label(_board, str(ORDER[i]), Vector3(cos(a), sin(a), 0) * (0.2 * SCALE) + Vector3(0, 0, 0.02), 18, Color("#E8DFC4"))
		l.pixel_size = 0.0012
	_reticle = Build.sphere(_board, 0.008, Vector3(0, 0, 0.03), Color("#FFE24A"), 2.0)
	_reticle.visible = false
	_chalk = Build.label(self, "", Vector3(0.75, 1.75, -OCHE + 0.06), 22, Color("#E8E4DA"))
	Build.box(self, Vector3(0.62, 0.8, 0.03), Vector3(0.75, 1.6, -OCHE + 0.03), Color("#22302A"), false) # chalkboard
	# Nothing on the floor to bump into: walk up and press E at the board itself.
	Build.area(self, Vector3(0.9, 0.9, 0.06), Vector3(0, 1.73, -OCHE + 0.03)) # thin, so the eye is never inside it
	set_view(Vector3(0, 1.72, -1.1), Vector3(0, 1.73, -OCHE)) # nearer than the oche, so the board reads


func _process(delta: float) -> void:
	var best: Dictionary = Game.instance.crew.get("darts", {}) if Game.instance != null else {}
	var names := best.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return int(best[a]) > int(best[b]))
	var chalk := "BEST TURNS\n"
	for n: String in names.slice(0, 5):
		chalk += "%s  %d\n" % [n, best[n]]
	_chalk.text = chalk
	if overlay == null:
		return
	# The hand sways: a slow drift you have to time the throw against.
	var t := Time.get_ticks_msec() / 1000.0
	var sway := Vector2(sin(t * 1.7) + 0.5 * sin(t * 4.1), cos(t * 1.3) + 0.5 * sin(t * 3.3)) * 0.018
	_reticle.visible = true
	_reticle.position = Vector3(_aim.x + sway.x, _aim.y + sway.y, 0.03)
	var total := 0
	for d in _darts:
		total += score(d)
	_lines[0].text = "DART %d / 3    THIS TURN %d    %s" % [mini(_darts.size() + 1, 3), total, "" if _darts.is_empty() else "last: %s" % _call(_darts[-1])]


func _build_overlay(root: Control) -> void:
	var box := UiKit.bottom_panel(root)
	box.add_child(UiKit.label("DARTS", 22, UiKit.BRASS))
	_lines.clear()
	var l := UiKit.label()
	box.add_child(l)
	_lines.append(l)
	box.add_child(UiKit.label("[mouse] aim   [LMB / Space] throw — mind the sway    " + footer(cluster != ""), 14, UiKit.DIM))


func on_leave() -> void:
	super.on_leave()
	_reticle.visible = false


func station_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_aim = (_aim + Vector2(event.relative.x, -event.relative.y) * 0.0006 * float(Settings.get_value("sensitivity"))).limit_length(BOARD_R + 0.05)
	elif (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or key_pressed(event, KEY_SPACE):
		_throw()


func _throw() -> void:
	if _darts.size() >= 3:
		_clear()
	var hit := Vector2(_reticle.position.x, _reticle.position.y) + Vector2(randf_range(-0.006, 0.006), randf_range(-0.006, 0.006))
	_darts.append(hit)
	var dart := Node3D.new()
	dart.position = Vector3(hit.x, hit.y, 0.02)
	_board.add_child(dart)
	Build.cyl(dart, 0.004, 0.09, Vector3(0, 0, 0.045), Color("#C9C9C9"), Vector3.BACK)
	Build.box(dart, Vector3(0.03, 0.03, 0.002), Vector3(0, 0, 0.09), Color("#C93A2E"), false)
	_stuck.append(dart)
	Sfx.play_at(_board, "click", Vector3(hit.x, hit.y, 0.0), 6.0, 0.6)
	if _darts.size() == 3:
		var total := 0
		for d in _darts:
			total += score(d)
		order("score", total)


func _clear() -> void:
	_darts.clear()
	for d in _stuck:
		d.queue_free()
	_stuck.clear()


## Points for a dart at `p` (m from the bull), by the real board's rings.
static func score(p: Vector2) -> int:
	var r := p.length() / SCALE
	if r <= 0.00635:
		return 50
	if r <= 0.0159:
		return 25
	if r > 0.170:
		return 0
	var ang := fposmod(90.0 - rad_to_deg(atan2(p.y, p.x)) + 9.0, 360.0)
	var n: int = ORDER[int(ang / 18.0) % 20]
	if r >= 0.162:
		return n * 2
	if r >= 0.099 and r <= 0.107:
		return n * 3
	return n


func _call(p: Vector2) -> String:
	var s := score(p)
	var r := p.length() / SCALE
	if s == 50:
		return "BULLSEYE!"
	if s == 0:
		return "off the board"
	return ("double %d" % (s / 2)) if r >= 0.162 else (("treble %d" % (s / 3)) if r >= 0.099 and r <= 0.107 else str(s))
