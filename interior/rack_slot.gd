class_name RackSlot
extends Node3D
## One tool on a rack. E takes it (or swaps for the one in hand).

var kind := ""
var _model: Node3D


func _ready() -> void:
	_model = Tools.model(kind)
	_model.rotation = Vector3(PI / 2.0, 0, 0) if kind in ["torch", "wrench", "whistle", "guitar", "bass", "synth", "fiddle"] else Vector3.ZERO
	add_child(_model)
	Build.area(self, Vector3(0.25, 0.4, 0.26), Vector3.ZERO)


func _process(_delta: float) -> void:
	if kind == "pump" and Game.instance != null:
		_model.visible = Game.instance.pumps_free() > 0
	elif Tools.is_instrument(kind) and Game.instance != null:
		_model.visible = Game.instance.instrument_free(kind)


func get_prompt(player: Player) -> String:
	if player.held_tool == kind:
		return "[E] hang the %s back up" % Tools.display_name(kind)
	if Tools.is_instrument(kind) and not Game.instance.instrument_free(kind):
		var who := 0
		for peer: int in Game.instance.crew.tools:
			if Game.instance.crew.tools[peer] == kind:
				who = peer
		return "The %s is out: %s has it" % [Tools.display_name(kind), Game.instance.crew_name(who)]
	if kind == "pump" and Game.instance.pumps_free() <= 0:
		return "No pumps left on the rack (%d aboard)" % Tools.PUMPS_ABOARD
	return "[E] take the %s" % Tools.display_name(kind)


func interact(player: Player) -> void:
	Game.instance.rq_tool.rpc_id(1, "" if player.held_tool == kind else kind)
