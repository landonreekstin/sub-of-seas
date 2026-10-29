class_name ToolRack
extends Node3D
## A wall board holding one of each tool. Built facing -X (mount it on the starboard
## wall; turn it PI for the port wall). Each tool hangs on its own pick-up slot.

const ORDER := ["torch", "extinguisher", "wrench", "pump"]


func _ready() -> void:
	Build.box(self, Vector3(0.05, 0.7, 1.3), Vector3(0.02, 0, 0), Color("#6B5A44"), false)
	Build.label(self, "DAMAGE CONTROL", Vector3(-0.01, 0.42, 0), 28, Color("#F2E8CF")).rotation.y = -PI / 2.0
	for i in ORDER.size():
		var slot := RackSlot.new()
		slot.kind = ORDER[i]
		slot.position = Vector3(-0.1, -0.05, -0.45 + i * 0.3)
		add_child(slot)
