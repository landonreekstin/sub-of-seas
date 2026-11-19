class_name EscapeTrunk
extends Node3D
## The escape trunk in the forward torpedo room's deckhead (Blaney: out of the sub while dived):
## up through it and out of the boat at the bow, in the dive suit when she's dived.


func _ready() -> void:
	var steel := Color("#5A6266")
	var top := SubInterior.DECK_HEIGHT
	Build.cyl(self, 0.55, 0.3, Vector3(0, top - 0.15, 0), steel) # the trunk's ring in the deckhead
	Build.cyl(self, 0.42, 0.06, Vector3(0, top - 0.32, 0), Color("#3A4044")) # its hatch
	Build.wheel(self, 0.16, Vector3(0, top - 0.38, 0), Color("#C9A04A"), Vector3.DOWN)
	for k in 5: # rungs up to it
		Build.box(self, Vector3(0.45, 0.04, 0.04), Vector3(0, 0.35 + k * 0.4, 0.5), steel, false)
	for side in [-1.0, 1.0]:
		Build.box(self, Vector3(0.04, top - 0.3, 0.04), Vector3(side * 0.24, (top - 0.3) * 0.5, 0.5), steel, false)
	var sign := Build.label(self, "ESCAPE TRUNK", Vector3(0, top - 0.55, 0.53), 22, UiKit.BRASS)
	sign.rotation.y = PI
	Build.area(self, Vector3(0.9, 1.2, 1.2), Vector3(0, top - 0.6, 0.3))


func get_prompt(_player: Player) -> String:
	return "[E] Escape trunk: out on deck at the bow" if Diving.water_y() <= 0.0 else "[E] Escape trunk: out into the sea at the bow (in a dive suit)"


func interact(player: Player) -> void:
	player.go_on_deck(true)
