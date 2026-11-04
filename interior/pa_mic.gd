class_name PaMic
extends Node3D
## The boat's PA microphone (Blaney): E, type what you want done, and the crew do it (CrewCommand,
## BotCrew). Faces forward from the bulkhead it is mounted on.


func _ready() -> void:
	var col := Color("#4A5248")
	Build.box(self, Vector3(0.5, 0.42, 0.1), Vector3(0, 1.45, 0), col)
	Build.label(self, "1MC", Vector3(0, 1.57, -0.06), 26, UiKit.BRASS).rotation.y = PI
	for i in 4: # the speaker slots
		Build.box(self, Vector3(0.28, 0.02, 0.012), Vector3(-0.06, 1.34 + i * 0.045, -0.055), Color("#22251F"), false)
	Build.cyl(self, 0.012, 0.3, Vector3(0.17, 1.28, -0.07), Color("#22251F"))
	var mic := Build.cyl(self, 0.038, 0.1, Vector3(0.17, 1.11, -0.07), Color("#8A8F86"))
	mic.rotation.x = 0.25
	Build.area(self, Vector3(0.6, 0.7, 0.3), Vector3(0, 1.35, -0.05))


func get_prompt(_player: Player) -> String:
	return "[E] PA microphone: tell the crew what to do"


func interact(_player: Player) -> void:
	Game.instance.open_pa()
