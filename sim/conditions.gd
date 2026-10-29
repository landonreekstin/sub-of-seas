class_name Conditions
extends RefCounted
## Weather, light and water for a patrol: night, sea state and the thermocline. They change
## what the enemy can see and hear (Detection reads them) and how the sea and the boat look.

const SEA_NAMES := ["calm", "moderate", "rough"]

var night := false
var sea_state := 1 ## 0 calm, 1 moderate, 2 rough
var layer_depth := 0.0 ## depth of the thermocline in metres; 0 = none


## Lookouts: night cuts their range hard; rough water hides a periscope's feather.
func visual_factor() -> float:
	return (0.3 if night else 1.0) * [1.2, 1.0, 0.65][sea_state]


## Hydrophones: rough seas drown things out.
func hearing_factor(sub_depth: float) -> float:
	return [1.1, 1.0, 0.7][sea_state] * (0.55 if below_layer(sub_depth) else 1.0)


## Active sonar bounces off the layer: a boat under it is hard to find.
func sonar_factor(sub_depth: float) -> float:
	return 0.4 if below_layer(sub_depth) else 1.0


func below_layer(sub_depth: float) -> bool:
	return layer_depth > 0.0 and sub_depth > layer_depth + 3.0


func describe() -> String:
	var bits: Array[String] = ["night" if night else "day", "%s sea" % SEA_NAMES[sea_state]]
	bits.append("a layer at %d m" % roundi(layer_depth) if layer_depth > 0.0 else "no layer")
	return ", ".join(bits)


func to_snapshot() -> Array:
	return [night, sea_state, layer_depth]


func apply_snapshot(a: Array) -> void:
	night = a[0]
	sea_state = a[1]
	layer_depth = a[2]
