class_name PartsCrate
extends Node3D
## The spare-parts boxes in stores. E takes one (or puts back the one in hand). Wrecked
## gear needs one fitted before the wrench can fix it; each fitted box is used up.

var _boxes: Array[MeshInstance3D] = []
var _label: Label3D


func _ready() -> void:
	Build.box(self, Vector3(0.9, 0.08, 0.7), Vector3(0, 0.04, 0), Color("#6B5A44"))
	for i in 8:
		var b := Build.box(self, Vector3(0.3, 0.18, 0.2), Vector3(-0.3 + (i % 3) * 0.3, 0.17 + (i / 6) * 0.19, -0.2 + ((i / 3) % 2) * 0.32), Color("#7A5A34"), false)
		_boxes.append(b)
	_label = Build.label(self, "", Vector3(0, 0.75, 0), 36)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	Build.area(self, Vector3(0.9, 0.6, 0.7), Vector3(0, 0.3, 0))


func _process(_delta: float) -> void:
	if Game.instance == null:
		return
	var left: int = Game.instance.crew.get("parts", 0)
	for i in _boxes.size():
		_boxes[i].visible = i < left
	_label.text = "SPARE PARTS ×%d" % left


func get_prompt(player: Player) -> String:
	if player.held_tool == "parts":
		return "[E] put the spare parts back"
	if Game.instance.crew.get("parts", 0) <= 0:
		return "Stores are out of spare parts"
	return "[E] take a spare parts box"


func interact(player: Player) -> void:
	Game.instance.rq_tool.rpc_id(1, "" if player.held_tool == "parts" else "parts")
