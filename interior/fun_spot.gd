class_name FunSpot
extends Node3D
## Marks something fun to do (Blaney: "glow when close"): walk within a few metres and it glows
## softly, warm, with its name over it. Every spot is also listed on the T card (ThingsToDo),
## with where it is and how to use it.

const GROUP := "fun_spots"
const NEAR := 3.5 ## metres: closer than this, it glows
const GLOW := Color("#FFC870")

var title := ""
var how := ""
var _light: OmniLight3D
var _label: Label3D
var _level := 0.0


## A spot on `parent` at `pos` (local), called `title`, used by `how` ("[E] take a seat ...").
static func add(parent: Node3D, title_text: String, how_text: String, pos: Vector3) -> FunSpot:
	var f := FunSpot.new()
	f.title = title_text
	f.how = how_text
	f.position = pos
	parent.add_child(f)
	return f


func _ready() -> void:
	add_to_group(GROUP)
	_light = OmniLight3D.new()
	_light.light_color = GLOW
	_light.omni_range = 1.6
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_light.visible = false
	add_child(_light)
	_label = Build.label(self, title.to_upper(), Vector3(0, 0.55, 0), 44, Color("#FFE2A8"))
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.outline_size = 8
	_label.outline_modulate = Color(0.1, 0.07, 0.03, 0.8)
	_label.visible = false


func _process(delta: float) -> void:
	var me: Player = Game.instance.local_player if Game.instance != null else null
	var near := me != null and me.station == null and me.global_position.distance_to(global_position) < NEAR
	_level = move_toward(_level, 1.0 if near else 0.0, delta * 2.5)
	_light.visible = _level > 0.0
	_light.light_energy = 1.2 * _level
	_label.visible = _level > 0.0
	_label.modulate.a = _level


## Which room it is in, by the boat's own names.
func room() -> String:
	return room_at(global_position)


static func room_at(p: Vector3) -> String:
	var i := Game.instance.interior if Game.instance != null else null
	if i == null or Sim.world == null:
		return ""
	if i.has_conning_tower and p.y > SubInterior.CT_FLOOR - 0.5:
		return "conning tower"
	var c: Dictionary = i.compartments[Sim.world.hull.comp_at_pos(p)]
	return String(c.get("name", c.get("type", "")))
