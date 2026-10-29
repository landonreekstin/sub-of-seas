class_name DamageSpot
extends Node3D
## One leak, fire or placed pump inside the boat, drawn from the hull state. The tool ray
## finds it through its Area3D; holding the right tool on it sends work to the host.

var kind := "" ## "leak" | "fire" | "pump"
var target_id := "" ## leak/fire id, or pump index
var amount := 0.0 ## leak hp / fire size, for the prompt
var _fx: CPUParticles3D
var _light: OmniLight3D


func setup(spot_kind: String, id: String) -> DamageSpot:
	kind = spot_kind
	target_id = id
	name = "%s_%s" % [kind, id]
	return self


func _ready() -> void:
	match kind:
		"leak":
			# Sprays inboard from the hull wall (position.x tells which side).
			var inward := Vector3(-signf(position.x), -0.15, 0)
			Build.sphere(self, 0.07, Vector3.ZERO, Color("#1E2A24"))
			_fx = Build.particles(self, Color(0.85, 0.93, 1.0, 0.85), 40, 0.7, inward, 4.0, 12.0, Vector3(0, -9, 0), 0.07)
			Build.area(self, Vector3(0.5, 0.6, 0.6), Vector3(-signf(position.x) * 0.2, 0, 0))
			Sfx.loop_at(self, "water_loop", Vector3.ZERO, -2.0)
		"fire":
			_fx = Build.particles(self, Color(1.0, 0.55, 0.15, 0.9), 50, 0.8, Vector3.UP, 1.2, 25.0, Vector3(0, 1.5, 0), 0.16)
			_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			_fx.emission_sphere_radius = 0.3
			_light = OmniLight3D.new()
			_light.light_color = Color("#FF8A3A")
			_light.omni_range = 4.0
			_light.position.y = 0.6
			add_child(_light)
			Build.area(self, Vector3(1.0, 1.2, 1.0), Vector3(0, 0.5, 0))
			Sfx.loop_at(self, "fire_loop", Vector3(0, 0.5, 0), 0.0)
		"pump":
			var m := Tools.model("pump")
			m.position.y = 0.11
			add_child(m)
			Build.area(self, Vector3(0.5, 0.4, 0.4), Vector3(0, 0.2, 0))


func set_amount(a: float) -> void:
	amount = a
	if kind == "fire":
		var s := clampf(a, 0.1, 1.0)
		_fx.scale_amount_min = 0.6 + s
		_fx.scale_amount_max = 1.0 + s * 1.5
		_fx.emission_sphere_radius = 0.2 + s * 0.4


func _process(_delta: float) -> void:
	if _light != null:
		_light.light_energy = (0.8 + amount * 1.6) * randf_range(0.75, 1.0)


func get_prompt(player: Player) -> String:
	var tool := player.held_tool
	match kind:
		"leak":
			if tool == "torch":
				return "[LMB] hold to weld the leak"
			return "Leak! Needs a welding torch"
		"fire":
			if tool == "extinguisher":
				return "[LMB] hold to put out the fire"
			return "FIRE! Needs an extinguisher"
		"pump":
			return "Pump running  —  [E] pick it up" if tool == "" else "Pump running"
	return ""


func interact(player: Player) -> void:
	if kind == "pump" and player.held_tool == "":
		Game.instance.rq_take_pump.rpc_id(1, int(target_id))


## The repair target for `tool`, or "" if that tool does nothing here.
func tool_target(tool: String) -> String:
	if (kind == "leak" and tool == "torch") or (kind == "fire" and tool == "extinguisher"):
		return target_id
	return ""
