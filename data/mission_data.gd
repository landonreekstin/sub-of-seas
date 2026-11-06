class_name MissionData
extends Resource
## One patrol: where the boat starts, which groups of ships are out there, and what the
## crew has to do. Positions in metres (x east, y north) from the boat's starting point.

## The patrols the host can pick, in menu order (the training patrol is separate).
const KEYS: Array[String] = ["convoy", "tankers", "hunted", "carrier", "task_force", "sub_duel", "sandbox", "cw_convoy", "cw_barrier", "cw_battlegroup", "cw_duel", "cw_sandbox", "cave", "cw_cave", "titan_dive", "titan_cave"]

@export var key := ""
@export var era := "ww2" ## ww2 | cold_war | modern: the boats it's offered to (SubClassData.era)
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
@export var deep_holes: Array[float] = [] ## floors this deep (m) dug into the sea floor: the first right under the start, the rest a few km off
@export var cave := false ## the cave challenge: a cave dead ahead to take her through, timed
@export var limited_map := false ## the chart and sand table only show what the boat has seen (ChartKnown)
@export var squalls := -1 ## rain squalls kept about the patrol; -1 = by sea state (calm 1, moderate 2, rough 3), 0 = clear
## Each: {type: convoy | task_force | hunter_killer, ships: [class keys], escorts: [class keys],
## pos: Vector2, course, speed (kn), radius (hunter_killer)}.
@export var groups: Array[Dictionary] = []
## Each: {kind: sink_class | sink_role | tonnage | survive | cave (through the cave) | deep (down to `value` m) | surface (back up, after the rest), class, role, count, value (t or s), text}.
@export var objectives: Array[Dictionary] = []


static func load_key(k: String) -> MissionData:
	var path := "res://data/missions/%s.tres" % k
	return load(path) if ResourceLoader.exists(path) else null
