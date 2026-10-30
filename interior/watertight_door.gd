class_name WatertightDoor
extends Node3D
## A hinged watertight door in a bulkhead opening. Open/shut state is owned by the host
## (crew.doors) so it matches for everyone; interacting asks the host to toggle it.

const WIDTH := 1.0
const HEIGHT := 1.9

var door_id := ""
var is_open := false
var _hinge: Node3D
var _tween: Tween
var _born := Time.get_ticks_msec()


func setup(id: String) -> WatertightDoor:
	door_id = id
	name = "door_" + id
	return self


func _ready() -> void:
	# Hinge on the port edge, on the aft face of the bulkhead (+Z side).
	_hinge = Node3D.new()
	_hinge.position = Vector3(-WIDTH * 0.5, 0, 0.14)
	add_child(_hinge)
	var slab := Build.box(_hinge, Vector3(WIDTH, HEIGHT, 0.08), Vector3(WIDTH * 0.5, HEIGHT * 0.5, 0), Color("#7E8C7A"))
	Build.wheel(slab, 0.16, Vector3(0, 0.1, 0.07), Color("#B23A2E"), Vector3.BACK)
	Build.wheel(slab, 0.16, Vector3(0, 0.1, -0.07), Color("#B23A2E"), Vector3.FORWARD)
	# Coaming around the opening.
	Build.box(self, Vector3(WIDTH + 0.2, 0.1, 0.3), Vector3(0, HEIGHT + 0.05, 0), Color("#C9A04A"), false)
	Build.box(self, Vector3(0.1, HEIGHT, 0.3), Vector3(-WIDTH * 0.5 - 0.05, HEIGHT * 0.5, 0), Color("#C9A04A"), false)
	Build.box(self, Vector3(0.1, HEIGHT, 0.3), Vector3(WIDTH * 0.5 + 0.05, HEIGHT * 0.5, 0), Color("#C9A04A"), false)


func get_prompt(_player: Player) -> String:
	return "[E] %s door" % ("Shut" if is_open else "Open")


func interact(_player: Player) -> void:
	Game.instance.rq_door.rpc_id(1, door_id)


func set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_hinge, "rotation:y", deg_to_rad(-100.0) if open else 0.0, 0.8)
	if Time.get_ticks_msec() - _born < 1000:
		return # the state a joiner arrives to, not someone working the door
	if open:
		Sfx.play_at(self, "door_open", Vector3(0, 1.0, 0.2))
	else:
		_tween.tween_callback(Sfx.play_at.bind(self, "clang", Vector3(0, 1.0, 0.2), 2.0))
