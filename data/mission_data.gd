class_name MissionData
extends Resource
## One patrol: where the boat starts, which groups of ships are out there, and what the
## crew has to do. Positions in metres (x east, y north) from the boat's starting point.

## The patrols the host can pick, in menu order (the training patrol is separate).
const KEYS: Array[String] = ["convoy", "tankers", "hunted", "carrier", "task_force", "sandbox"]

@export var key := ""
@export var title := ""
@export_multiline var briefing := ""
@export var difficulty := 1 ## 1..5, shown in the menu
@export var sandbox := false ## open ocean: ships come and go (Sandbox), no objectives, home when you like
@export var start_heading := 0.0
@export var start_depth := -1.0 ## metres; -1 = periscope depth, 0 = surfaced
@export var start_speed := 1 ## telegraph
@export var battery := 0.8
@export var night := false
@export var sea_state := 1 ## 0 calm, 1 moderate, 2 rough
@export var layer_depth := 0.0 ## thermocline depth in metres, 0 = none
## Each: {type: convoy | task_force | hunter_killer, ships: [class keys], escorts: [class keys],
## pos: Vector2, course, speed (kn), radius (hunter_killer)}.
@export var groups: Array[Dictionary] = []
## Each: {kind: sink_class | sink_role | tonnage | survive, class, role, count, value (t or s), text}.
@export var objectives: Array[Dictionary] = []


static func load_key(k: String) -> MissionData:
	var path := "res://data/missions/%s.tres" % k
	return load(path) if ResourceLoader.exists(path) else null
