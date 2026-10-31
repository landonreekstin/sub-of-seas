class_name WeatherView
extends Node3D
## The rain squalls in the exterior world: each a dark, lumpy cloud base with a curtain of rain
## hanging under it to the sea, and, when the eye is under one, rain streaking down past it.
## ExteriorWorld darkens the sky, thickens the fog and roughens the sea by `rain_here`.

const CURTAIN := preload("res://world/rain_curtain.gdshader")
const CLOUD_BASE := 520.0 ## metres up
const CURTAIN_HEIGHT := 560.0

var rain_here := 0.0 ## 0..1, how hard it is raining on the eye
var _squalls := {} ## index -> Node3D (rebuilt when the set changes)
var _key := ""
var _drops: CPUParticles3D
var _cloud_mat: Material
var _drop_mat: StandardMaterial3D


func _ready() -> void:
	var cm := StandardMaterial3D.new() # plain: the toon detail map turns to grain this big
	cm.albedo_color = Color("#5E6670")
	cm.roughness = 1.0
	_cloud_mat = cm
	_drops = CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.02, 1.2)
	var m := StandardMaterial3D.new()
	_drop_mat = m
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.albedo_color = Color(0.85, 0.9, 0.95, 0.6)
	quad.material = m
	_drops.mesh = quad
	_drops.amount = 1800
	_drops.lifetime = 0.7
	_drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_drops.emission_box_extents = Vector3(28.0, 0.5, 28.0)
	_drops.direction = Vector3.DOWN
	_drops.spread = 4.0
	_drops.initial_velocity_min = 26.0
	_drops.initial_velocity_max = 32.0
	_drops.gravity = Vector3(0, -9.8, 0)
	_drops.emitting = false
	add_child(_drops)


## Places the squalls and the drops round `eye` (world position), from `c`.
func sync(c: Conditions, eye: Vector3) -> void:
	var key := str(c.squalls.size())
	if key != _key:
		_key = key
		for n: Node3D in _squalls.values():
			n.queue_free()
		_squalls.clear()
		for i in c.squalls.size():
			_squalls[i] = _make_squall(i)
	for i in c.squalls.size():
		var s: Array = c.squalls[i]
		var node: Node3D = _squalls[i]
		var strength := Conditions.squall_strength(s)
		var radius: float = s[2]
		node.position = ExteriorWorld.to_3d(Vector2(s[0], s[1]))
		node.scale = Vector3(radius, 1.0, radius)
		node.visible = strength > 0.02
		var curtain: MeshInstance3D = node.get_node("Curtain")
		var cm := curtain.material_override as ShaderMaterial
		cm.set_shader_parameter("strength", strength)
		cm.set_shader_parameter("color", Color(0.1, 0.13, 0.18) if c.night else Color(0.36, 0.40, 0.45))
		var cloud: Node3D = node.get_node("Cloud")
		var grow := lerpf(0.4, 1.0, strength)
		cloud.scale = Vector3(grow, 1.0, grow)
	var at := Vector2(eye.x, -eye.z)
	rain_here = c.rain_at(at)
	_drops.emitting = rain_here > 0.05 and eye.y > -0.5
	_drop_mat.albedo_color.a = 0.6 * clampf(rain_here, 0.2, 1.0)
	_drops.position = eye + Vector3(0, 14.0, 0)


## A squall of radius 1 (scaled by its radius in x and z): a curtain of rain under a cloud.
func _make_squall(i: int) -> Node3D:
	var node := Node3D.new()
	add_child(node)
	var curtain := MeshInstance3D.new()
	curtain.name = "Curtain"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.8
	cyl.bottom_radius = 0.85
	cyl.height = CURTAIN_HEIGHT
	cyl.radial_segments = 40
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	curtain.mesh = cyl
	curtain.position.y = CURTAIN_HEIGHT * 0.5
	var mat := ShaderMaterial.new()
	mat.shader = CURTAIN
	curtain.material_override = mat
	curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(curtain)
	# The cloud base: flattened dark lumps, a few piled on each other. Built in a counter-scaled
	# node so they stay round while the squall node stretches in x and z.
	var cloud := Node3D.new()
	cloud.name = "Cloud"
	node.add_child(cloud)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (i + 1)
	for k in 14:
		var lump := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radial_segments = 16
		sm.rings = 8
		lump.mesh = sm
		lump.material_override = _cloud_mat
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, 0.65) if k > 0 else 0.0
		var w := rng.randf_range(0.4, 0.75)
		var tall := rng.randf_range(160.0, 320.0) * (1.0 - d * 0.6) # piled highest in the middle
		lump.position = Vector3(cos(a) * d, CLOUD_BASE + tall * 0.35, sin(a) * d)
		lump.scale = Vector3(w, tall, w)
		lump.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cloud.add_child(lump)
	return node
