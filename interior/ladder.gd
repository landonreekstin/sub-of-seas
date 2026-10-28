class_name Ladder
extends Node3D
## A vertical ladder between two decks. Interacting at either end climbs the player along
## a fixed path to the other end, so nobody gets stuck on rungs.

var bottom_path: Array[Vector3] = [] ## global points, climbing up from the bottom
var label_up := "Climb up"
var label_down := "Climb down"
var top_y := 0.0


func get_prompt(player: Player) -> String:
	return "[E] %s" % (label_down if player.global_position.y > top_y - 0.5 else label_up)


func interact(player: Player) -> void:
	var path := bottom_path.duplicate()
	if player.global_position.y > top_y - 0.5:
		path.reverse()
	player.climb(path)
