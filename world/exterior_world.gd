class_name ExteriorWorld
extends Node3D
## The ocean outside, in its own World3D inside a SubViewport. Rendered only while someone
## local is looking through the periscope. Sim plane (x east, y north) maps to 3D (x, -z).

const OCEAN_SHADER := preload("res://world/ocean.gdshader")
const NEAR_OCEAN_SIZE := 4000.0
const GRID_SNAP := 50.0

var viewport: SubViewport
var camera: Camera3D
var scope_bearing := 0.0 ## relative bearing, set by the periscope station
var scope_fov := 32.0
var _ocean_near: MeshInstance3D
var _ocean_far: MeshInstance3D
var _ships := {} ## ship id -> Node3D
var _tracks := {} ## torpedo id -> {from, head (3D xz), ended (sim time, or -1 while running)}
var _planes := {} ## aircraft id -> Node3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _look := "" ## the conditions last applied to the sky, sun and sea


static func to_3d(p: Vector2, y := 0.0) -> Vector3:
	return Vector3(p.x, y, -p.y)


static func create() -> ExteriorWorld:
	var w := ExteriorWorld.new()
	w.viewport = SubViewport.new()
	w.viewport.own_world_3d = true
	w.viewport.size = Vector2i(1280, 720)
	w.viewport.msaa_3d = Viewport.MSAA_2X
	w.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	w.viewport.add_child(w)
	return w


func _ready() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	_sky = sky_mat
	sky_mat.sky_top_color = Color("#3F7FBF")
	sky_mat.sky_horizon_color = Color("#BFD8E8")
	sky_mat.ground_horizon_color = Color("#BFD8E8")
	sky_mat.ground_bottom_color = Color("#1F4E79")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	_env = env
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Flat ambient and no sky reflections: stylised, and keeps the sea from washing out white.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8FA8BF")
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("#BFD8E8")
	env.fog_density = 0.00004
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	_sun = sun
	sun.rotation_degrees = Vector3(-35.0, -40.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 600.0
	add_child(sun)

	var mat := ShaderMaterial.new()
	mat.shader = OCEAN_SHADER
	_ocean_near = MeshInstance3D.new()
	var near := PlaneMesh.new()
	near.size = Vector2(NEAR_OCEAN_SIZE, NEAR_OCEAN_SIZE)
	near.subdivide_width = 400
	near.subdivide_depth = 400
	_ocean_near.mesh = near
	_ocean_near.material_override = mat
	add_child(_ocean_near)
	_ocean_far = MeshInstance3D.new()
	var far := PlaneMesh.new()
	far.size = Vector2(80000.0, 80000.0)
	_ocean_far.mesh = far
	_ocean_far.material_override = mat
	_ocean_far.position.y = -0.3
	add_child(_ocean_far)

	camera = Camera3D.new()
	camera.far = 30000.0
	camera.near = 0.2
	camera.current = true
	add_child(camera)


func set_active(on: bool) -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func _process(_delta: float) -> void:
	if Sim.world == null:
		return
	var sub := Sim.world.sub
	var h := sub.scope_height()
	camera.position = to_3d(sub.pos, maxf(h, 0.5) if h > 0.0 else maxf(h, -4.0))
	camera.rotation = Vector3(0.0, -deg_to_rad(sub.heading + scope_bearing), 0.0)
	camera.fov = scope_fov
	var snap := Vector3(snappedf(camera.position.x, GRID_SNAP), 0.0, snappedf(camera.position.z, GRID_SNAP))
	_ocean_near.position = snap
	_ocean_far.position = Vector3(snap.x, -0.3, snap.z)
	_sync_ships()
	_sync_torpedoes()
	_sync_planes()
	_feed_wakes()
	_apply_conditions(Sim.world.conditions)
	_underwater(sub.scope_height() <= 0.0)


func _sync_ships() -> void:
	var seen := {}
	for ship in Sim.world.ships:
		seen[ship.id] = true
		var node: Node3D = _ships.get(ship.id)
		if node == null:
			node = ShipModels.build(ship.data)
			add_child(node)
			_ships[ship.id] = node
		var hit := ship.hp < ship.data.hp
		if hit and not node.has_node("Burning") and (ship.data.burns or ship.is_sinking()):
			_set_burning(node, ship.data)
		var bob := sin(Sim.world.time * 0.7 + ship.id) * 0.3
		node.position = to_3d(ship.pos, bob - ship.sink * 30.0)
		node.rotation = Vector3(ship.sink * 0.35, -deg_to_rad(ship.heading), ship.sink * 0.5 + sin(Sim.world.time * 0.5 + ship.id) * 0.02)
	for id: int in _ships.keys():
		if not seen.has(id):
			_ships[id].queue_free()
			_ships.erase(id)


## The ocean shader draws the nearest ships' wakes.
func _feed_wakes() -> void:
	var data := PackedVector4Array()
	var lens := PackedFloat32Array()
	var near := Sim.world.ships.duplicate()
	var here := Sim.world.sub.pos
	near.sort_custom(func(a: ShipState, b: ShipState) -> bool: return a.pos.distance_squared_to(here) < b.pos.distance_squared_to(here))
	for ship: ShipState in near.slice(0, 16):
		data.append(Vector4(ship.pos.x, -ship.pos.y, deg_to_rad(ship.heading), ship.speed))
		lens.append(ship.data.length)
	data.resize(16)
	lens.resize(16)
	for m: ShaderMaterial in [_ocean_near.material_override, _ocean_far.material_override]:
		m.set_shader_parameter("ships", data)
		m.set_shader_parameter("ship_len", lens)
		m.set_shader_parameter("ship_count", mini(near.size(), 16))


## Night: a dark blue sky, a dim cold moon, black water with silver foam. Sea state sets the
## height of the waves.
func _apply_conditions(c: Conditions) -> void:
	var key := "%s/%d" % [c.night, c.sea_state]
	if key == _look:
		return
	_look = key
	_sky.sky_top_color = Color("#0B1426") if c.night else Color("#3F7FBF")
	_sky.sky_horizon_color = Color("#22324A") if c.night else Color("#BFD8E8")
	_sky.ground_horizon_color = _sky.sky_horizon_color
	_sky.ground_bottom_color = Color("#050A12") if c.night else Color("#1F4E79")
	_sun.light_energy = 0.25 if c.night else 1.2
	_sun.light_color = Color("#9DB4D8") if c.night else Color.WHITE
	_env.ambient_light_color = Color("#2A3A55") if c.night else Color("#8FA8BF")
	_env.ambient_light_energy = 0.35 if c.night else 0.55
	if _env.fog_density < 0.01:
		_env.fog_light_color = _sky.sky_horizon_color
	var m := _ocean_near.material_override as ShaderMaterial
	m.set_shader_parameter("amplitude", [0.3, 0.5, 0.9][c.sea_state])
	m.set_shader_parameter("horizon_color", Color(0.12, 0.17, 0.26) if c.night else Color(0.55, 0.70, 0.82))
	m.set_shader_parameter("shallow_color", Color(0.02, 0.08, 0.12) if c.night else Color(0.06, 0.30, 0.38))


## With the scope just under, the view is murky green water instead of nothing.
func _underwater(under: bool) -> void:
	if under == (_env.fog_density > 0.01):
		return
	_env.fog_density = 0.08 if under else 0.00004
	_env.fog_light_color = Color("#1D4A52") if under else _sky.sky_horizon_color
	_env.fog_sky_affect = 1.0 if under else 0.0


func _sync_planes() -> void:
	var seen := {}
	for p in Sim.world.planes:
		seen[p.id] = true
		var node: Node3D = _planes.get(p.id)
		if node == null:
			node = ShipModels.plane()
			add_child(node)
			_planes[p.id] = node
		node.position = to_3d(p.pos, p.altitude)
		node.rotation = Vector3(0.0, -deg_to_rad(p.heading), sin(Sim.world.time * 0.8 + p.id) * 0.15)
	for id: int in _planes.keys():
		if not seen.has(id):
			_planes[id].queue_free()
			_planes.erase(id)


## Only the bubble track shows on the surface, from where the fish left the tube to where it
## is (or hit, or ran out); the ocean shader draws it, and it fades about a minute later.
func _sync_torpedoes() -> void:
	var now := Sim.world.time
	var seen := {}
	for t in Sim.world.torpedoes:
		if not t.alive:
			continue
		seen[t.id] = true
		var head := Vector2(t.pos.x, -t.pos.y)
		if not _tracks.has(t.id):
			_tracks[t.id] = {"from": head, "head": head, "ended": -1.0}
		_tracks[t.id].head = head
		_tracks[t.id].ended = -1.0
	for id: int in _tracks.keys():
		var tr: Dictionary = _tracks[id]
		if not seen.has(id) and tr.ended < 0.0:
			tr.ended = now
		if tr.ended >= 0.0 and now - tr.ended > 90.0:
			_tracks.erase(id)
	var ids := _tracks.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return a > b) # newest first
	var segs := PackedVector4Array()
	var life := PackedVector2Array()
	for id: int in ids.slice(0, 8):
		var tr: Dictionary = _tracks[id]
		segs.append(Vector4(tr.from.x, tr.from.y, tr.head.x, tr.head.y))
		life.append(Vector2(0.0 if tr.ended < 0.0 else now - tr.ended, Torpedo.SPEED))
	var count := segs.size()
	segs.resize(8)
	life.resize(8)
	for m: ShaderMaterial in [_ocean_near.material_override, _ocean_far.material_override]:
		m.set_shader_parameter("torps", segs)
		m.set_shader_parameter("torp_life", life)
		m.set_shader_parameter("torp_count", count)


## Fire and a column of black smoke on a hit tanker, or any ship going down: on the horizon
## that's the first thing you see.
func _set_burning(node: Node3D, data: ShipClassData) -> void:
	var fx := Node3D.new()
	fx.name = "Burning"
	node.add_child(fx)
	var big := data.burns
	var fire := Build.particles(fx, Color("#FF8A2A"), 40, 1.2, Vector3.UP, 8.0, 25.0, Vector3(0, 2, 0), 6.0 if big else 3.5)
	fire.position = Vector3(0, 6, data.length * 0.1)
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fire.emission_box_extents = Vector3(data.beam * 0.35, 1.0, data.length * (0.3 if big else 0.1))
	var smoke := Build.particles(fx, Color(0.12, 0.12, 0.12, 0.8), 60, 9.0, Vector3.UP, 9.0, 12.0, Vector3(1.5, 1.0, 0), 14.0 if big else 9.0)
	smoke.position = Vector3(0, 12, data.length * 0.1)


## Water column and flash where a torpedo hit.
## A depth charge going off: a dome of white water, no flame.
func water_column(p: Vector2, depth: float) -> void:
	var fx := Node3D.new()
	fx.position = to_3d(p)
	add_child(fx)
	var h := clampf(40.0 - depth * 0.2, 12.0, 35.0)
	var dome := Build.sphere(fx, 6.0, Vector3.ZERO, Color(0.92, 0.95, 0.97, 0.9))
	var tw := fx.create_tween()
	tw.tween_property(dome, "scale", Vector3(2.2, h / 6.0, 2.2), 1.0).set_ease(Tween.EASE_OUT)
	tw.tween_property(dome, "scale", Vector3(3.5, 0.05, 3.5), 3.0).set_ease(Tween.EASE_IN)
	tw.tween_callback(fx.queue_free)


func explosion(p: Vector2) -> void:
	var fx := Node3D.new()
	fx.position = to_3d(p)
	add_child(fx)
	var column := Build.cyl(fx, 7.0, 1.0, Vector3.ZERO, Color(0.95, 0.97, 1.0, 0.9))
	var flash := Build.sphere(fx, 8.0, Vector3(0, 3, 0), Color("#FF9A3A"), 4.0)
	var tw := fx.create_tween().set_parallel(true)
	tw.tween_property(column, "scale", Vector3(1.6, 55.0, 1.6), 1.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(column, "position:y", 27.0, 1.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "scale", Vector3.ONE * 2.5, 0.4)
	tw.tween_property(flash, "visible", false, 0.0).set_delay(0.5)
	tw.chain().tween_property(column, "scale", Vector3(3.0, 0.1, 3.0), 2.5).set_ease(Tween.EASE_IN)
	tw.tween_property(column, "position:y", 0.0, 2.5).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(fx.queue_free)
