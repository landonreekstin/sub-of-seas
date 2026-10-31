class_name InstrumentRack
extends Node3D
## The band's instruments on a wall board, one of each (Tools.INSTRUMENTS, Band): E takes one,
## LMB held plays it anywhere aboard. Built facing -X like the tool racks (turn PI for port).


func _ready() -> void:
	Build.box(self, Vector3(0.05, 1.1, 2.1), Vector3(0.02, 0, 0), Color("#6B4A2E"), false)
	var title := Build.label(self, "SHIP'S BAND — %s" % Band.SONG.to_upper(), Vector3(-0.01, 0.66, 0), 24, Color("#F2E8CF"))
	title.rotation.y = -PI / 2.0
	for i in Tools.INSTRUMENTS.size():
		var slot := RackSlot.new()
		slot.kind = Tools.INSTRUMENTS[i]
		slot.position = Vector3(-0.14, 0.27 - (i / 4) * 0.52, -0.78 + (i % 4) * 0.52)
		slot.scale = Vector3.ONE * 0.6
		add_child(slot)
		var l := Build.label(self, Tools.display_name(slot.kind), slot.position + Vector3(0.1, -0.21, 0), 14, Color("#F2E8CF"))
		l.rotation.y = -PI / 2.0
