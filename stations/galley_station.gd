class_name GalleyStation
extends Station
## The galley range (Blaney: cooking in the galley): take over from the cook and fry up his
## special. The heat needle swings; Space flips it in the pan, and a flip in the green is a good
## one. Three flips make a meal, called out to the boat (Pastimes.meal). The cook steps aside
## while someone else has his stove.

const FLIPS := 3

var cook: Node3D ## Living's cook, hidden while the stove is taken
var pan := Vector3(0, 0.955, -0.63) ## the frying pan, local
var _food: Node3D
var _t := 0.0
var _speed := 1.0
var _zone := 0.0 ## the green, -1..1 across the gauge
var _good := 0
var _flips := 0
var _last := ""
var _lines: Array[Label] = []


func _ready() -> void:
	Build.area(self, Vector3(0.7, 0.4, 0.6), pan + Vector3(0, 0.1, 0.05))
	set_view(Vector3(0, 1.62, -0.05), pan)
	bot_arms = Vector2(0.7, 1.0)
	bot_lean = 0.15
	_food = Node3D.new()
	_food.position = pan + Vector3(0, 0.03, 0)
	add_child(_food)
	for e in 3:
		Build.cyl(_food, 0.035, 0.015, Vector3((e - 1) * 0.06, 0, (e % 2) * 0.05 - 0.02), Color("#C89048"))


## Where the needle points now, -1..1.
func needle() -> float:
	return sin(_t * _speed * 2.2) * 0.85 + sin(_t * _speed * 3.7) * 0.15


func _process(delta: float) -> void:
	if cook != null and Game.instance != null:
		cook.visible = Game.instance.station_occupant(station_id) == 0
	if overlay == null:
		return
	_t += delta
	var cells := 31
	var at := clampi(roundi((needle() + 1.0) * 0.5 * (cells - 1)), 0, cells - 1)
	var lo := roundi((_zone - 0.2 + 1.0) * 0.5 * (cells - 1))
	var hi := roundi((_zone + 0.2 + 1.0) * 0.5 * (cells - 1))
	var gauge := ""
	for k in cells:
		gauge += "▼" if k == at else ("█" if k >= lo and k <= hi else "─")
	_lines[0].text = "COLD  %s  SCORCHING" % gauge
	_lines[1].text = "Flip %d of %d    good flips %d    %s" % [mini(_flips + 1, FLIPS), FLIPS, _good, _last]


func on_enter() -> void:
	_new_dish()


func _new_dish() -> void:
	_flips = 0
	_good = 0
	_last = ""
	_next_flip()


func _next_flip() -> void:
	_zone = randf_range(-0.6, 0.6)
	_speed = randf_range(0.9, 1.5) + _flips * 0.25 # each flip a little harder


func _build_overlay(root: Control) -> void:
	var box := UiKit.bottom_panel(root)
	box.add_child(UiKit.label("THE COOK'S SPECIAL", 22, UiKit.BRASS))
	_lines.clear()
	for k in 2:
		var l := UiKit.label()
		box.add_child(l)
		_lines.append(l)
	box.add_child(UiKit.label("[Space] flip it when the needle is in the green    " + footer(false), 14, UiKit.DIM))


func station_input(event: InputEvent) -> void:
	if not key_pressed(event, KEY_SPACE) or event.is_echo():
		return
	var good := absf(needle() - _zone) <= 0.2
	_good += 1 if good else 0
	_flips += 1
	_last = "Perfect flip!" if good else ("Too cold..." if needle() < _zone else "Scorched it!")
	var tw := _food.create_tween()
	tw.tween_property(_food, "position:y", pan.y + 0.2, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(_food, "position:y", pan.y + 0.03, 0.15).set_ease(Tween.EASE_IN)
	_food.rotation.y += PI * 0.7
	click(-2.0, 0.5)
	if _flips >= FLIPS:
		order("meal", _good)
		_new_dish()
	else:
		_next_flip()
