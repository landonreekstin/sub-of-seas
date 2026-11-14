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
var eye_mode := "scope" ## "scope": the periscope's eye; "gun": the deck gun's sight, set by the gun station; "deck": a crewman out on deck (Deck)
var deck_eye := Transform3D.IDENTITY ## the deck crewman's eye in our boat's own space, set by Deck
var deck_fov := 75.0
var gun_bearing := 0.0 ## the gun's training, relative to the bow
var gun_fov := 45.0
var gun_range := 1500.0 ## the range on the sight: the line of sight comes down to the sea there
var _own: Node3D ## our own boat, on render layer OWN_LAYER: seen from the gun, the deck and the outside cameras, never the periscope or portholes (they are inside it)
const OWN_LAYER := 2
var _ocean_near: MeshInstance3D
var _ocean_far: MeshInstance3D
var _ships := {} ## ship id -> Node3D
var _tracks := {} ## torpedo id -> {from, head (3D xz), ended (sim time, or -1 while running)}
var _planes := {} ## aircraft id -> Node3D
var _env: Environment
var _sky: ToonSky
var _sun: DirectionalLight3D
var _look := "" ## the conditions last applied to the sky, sun and sea
var _terrain: TerrainView
var _floor_life: SeaFloorLife
var _life: SeaLifeView
var _weather: WeatherView
var _under := false ## the eye is under the surface (the sky shows the water's light instead)
var _floods: Array[SpotLight3D] = [] ## our boat's floodlights, on while she's dived
static var shore := 0.0 ## 0 open ocean .. 1 shallow water by an island: the light the sea lets down near the boat (paint_water)
static var _shore_at := Vector2(INF, INF)


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
	var sky_mat := ToonSky.new()
	_sky = sky_mat
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
	env.fog_density = 0.00002 # light haze: islands still read 10 km off
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
	near.subdivide_width = 300 # 13 m cells: the ripples are in the shader; 400 cost every view 140k more triangles (Blaney: save frames)
	near.subdivide_depth = 300
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

	_terrain = TerrainView.new()
	add_child(_terrain)
	_floor_life = SeaFloorLife.new()
	add_child(_floor_life)
	_life = SeaLifeView.new()
	add_child(_life)
	_weather = WeatherView.new()
	add_child(_weather)

	camera = Camera3D.new()
	camera.far = 30000.0
	camera.near = 1.0
	camera.current = true
	add_child(camera)


func set_active(on: bool) -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func _process(delta: float) -> void:
	if Sim.world == null:
		return
	var sub := Sim.world.sub
	var h := sub.scope_height()
	_place_own(sub)
	camera.cull_mask = 0xFFFFF if eye_mode in ["deck", "gun"] else 0xFFFFF & ~OWN_LAYER
	if eye_mode == "deck":
		camera.global_transform = _own.global_transform * deck_eye
		camera.fov = deck_fov
	elif eye_mode == "gun":
		var eye := _own.get_node("Gun/Eye") as Node3D
		eye.rotation.x = -atan2(eye.global_position.y, gun_range) # laid on the waterline at the set range
		camera.global_transform = eye.global_transform
		camera.fov = gun_fov
	else:
		camera.position = to_3d(sub.pos, maxf(h, 0.5) if h > 0.0 else maxf(h, -4.0))
		camera.rotation = Vector3(0.0, -deg_to_rad(sub.heading + scope_bearing), 0.0)
		camera.fov = scope_fov
	var snap := Vector3(snappedf(camera.position.x, GRID_SNAP), 0.0, snappedf(camera.position.z, GRID_SNAP))
	_ocean_near.position = snap
	_ocean_far.position = Vector3(snap.x, -0.3, snap.z)
	_terrain.sync(Sim.world.seabed)
	_floor_life.sync(sub.pos, Sim.world.seabed)
	_life.sync(delta)
	_sync_ships()
	_sync_torpedoes()
	_sync_planes()
	_feed_wakes()
	_weather.sync(Sim.world.conditions, camera.position)
	_feed_squalls(Sim.world.conditions)
	_apply_conditions(Sim.world.conditions)
	_update_shore(sub, delta)
	_light_under(sub)
	if eye_mode == "deck":
		_underwater(maxf(-camera.position.y, 0.01) if camera.position.y < 0.0 else 0.0)
	else:
		_underwater(maxf(-camera.position.y, 0.01) if h <= 0.0 and eye_mode != "gun" else 0.0)


## The sun is one light for the whole ocean, and every eye under water is round our boat: it
## dims with her depth so what's down there is lit no brighter than the water lets it be.
## Her floodlights come on once she's dived.
func _light_under(sub: SubState) -> void:
	var day := (0.25 if Sim.world.conditions.night else 1.2) * lerpf(1.0, 0.35, snappedf(_weather.rain_here, 0.05))
	var dived := sub.depth > sub.data.periscope_depth * 0.5
	_sun.light_energy = day * (water_light(maxf(sub.depth - 4.0, 0.0), shore, false) if dived else 1.0)
	_sun.shadow_enabled = not dived # down there the sun is too dim to cast them: a shadow pass saved in every view
	if _floods.is_empty() and _own != null:
		var d := ShipModels.own_dims(sub.data)
		for f: Array in [[Vector3(0, float(d.deck) - 0.5, -float(d.length) * 0.5 + 2.0), Vector3(0, -0.35, -1)], # bow, ahead and a little down
				[Vector3(0, -3.0, -float(d.length) * 0.15), Vector3(0, -1, -0.25)]]: # under the keel, down on the floor
			var l := SpotLight3D.new()
			l.light_color = Color("#E8F4FF")
			l.light_energy = 6.0
			l.spot_range = 70.0
			l.spot_angle = 32.0
			l.spot_attenuation = 1.2
			l.shadow_enabled = false
			l.position = f[0]
			var aim := (f[1] as Vector3).normalized()
			l.basis = Basis.looking_at(aim, Vector3.UP if absf(aim.y) < 0.9 else Vector3.FORWARD)
			_own.add_child(l)
			_floods.append(l)
	for l in _floods:
		l.visible = dived


## Puts everything drawn under `n` on our own boat's render layer.
static func set_own_layer(n: Node) -> void:
	for m in [n] + n.find_children("*", "VisualInstance3D", true, false):
		if m is VisualInstance3D:
			(m as VisualInstance3D).layers = OWN_LAYER


## Our own boat model (for the figures of the crew out on deck), or null before it is placed.
func own_boat() -> Node3D:
	return _own


## Our own boat under the gun crew, riding the swell, with the gun trained.
func _place_own(sub: SubState) -> void:
	if _own == null:
		_own = ShipModels.own_boat(sub.data)
		add_child(_own)
		set_own_layer(_own)
	var t := Sim.world.time
	var sea := Sim.world.conditions.sea_at(sub.pos)
	var under := sub.depth if sub.depth > 1.0 else 0.0 # dived, she's down there for the outside cameras
	_own.position = to_3d(sub.pos, sin(t * 0.7) * 0.15 * (1.0 + sea) - under + sub.breach_lift())
	_own.rotation = Vector3(sin(t * 0.45) * 0.006 * (1.0 + sea) + (deg_to_rad(sub.pitch) if sub.breach > 0.0 else 0.0), -deg_to_rad(sub.heading), sin(t * 0.6) * 0.012 * (1.0 + sea))
	(_own.get_node("Gun") as Node3D).rotation.y = -deg_to_rad(gun_bearing)


## Our deck gun fires: a flash and a puff of smoke at the muzzle, the barrel slamming back.
func gun_fired() -> void:
	if _own == null or not _own.visible:
		return
	var barrel: Node3D = _own.get_node("Gun/Barrel")
	var muzzle: Node3D = barrel.get_node("Muzzle")
	var fx := Node3D.new()
	add_child(fx)
	fx.global_transform = muzzle.global_transform
	var flash := Build.sphere(fx, 0.6, Vector3.ZERO, Color("#FFC36A"), 6.0)
	var smoke := Build.particles(fx, Color(0.8, 0.8, 0.78, 0.45), 14, 1.6, Vector3.FORWARD, 7.0, 20.0, Vector3(0, 0.6, 0), 0.7)
	smoke.one_shot = true
	smoke.explosiveness = 0.9
	smoke.local_coords = false
	var tw := fx.create_tween()
	tw.tween_property(flash, "scale", Vector3.ONE * 2.5, 0.06)
	tw.tween_property(flash, "visible", false, 0.0)
	tw.tween_interval(3.0)
	tw.tween_callback(fx.queue_free)
	var kick := barrel.create_tween()
	kick.tween_property(barrel, "position:z", 0.45, 0.05)
	kick.tween_property(barrel, "position:z", 0.0, 0.5).set_ease(Tween.EASE_OUT)


## Fall of shot: a round from our gun going into the sea, a tall thin white splash.
func shell_splash(p: Vector2) -> void:
	var fx := Node3D.new()
	fx.position = to_3d(p)
	add_child(fx)
	var col := Build.cyl(fx, 3.0, 1.0, Vector3.ZERO, Color(0.95, 0.97, 1.0, 0.95))
	var tw := fx.create_tween()
	tw.tween_property(col, "scale", Vector3(1.3, 30.0, 1.3), 0.6).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(col, "position:y", 15.0, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(col, "scale", Vector3(3.5, 0.1, 3.5), 2.2).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(col, "position:y", 0.0, 2.2).set_ease(Tween.EASE_IN)
	tw.tween_callback(fx.queue_free)


## A round from our gun bursting on a ship: a flash and a puff of black smoke on her side.
func shell_burst(p: Vector2) -> void:
	var fx := Node3D.new()
	fx.position = to_3d(p, 4.0)
	add_child(fx)
	var flash := Build.sphere(fx, 2.5, Vector3.ZERO, Color("#FF9A3A"), 5.0)
	var smoke := Build.particles(fx, Color(0.1, 0.1, 0.1, 0.85), 30, 4.0, Vector3.UP, 6.0, 40.0, Vector3(0.8, 1.5, 0), 5.0)
	smoke.one_shot = true
	smoke.explosiveness = 0.8
	var tw := fx.create_tween()
	tw.tween_property(flash, "scale", Vector3.ONE * 2.0, 0.12)
	tw.tween_property(flash, "visible", false, 0.0)
	tw.tween_interval(5.0)
	tw.tween_callback(fx.queue_free)


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
		if hit and not node.has_node("Burning") and not ship.submerged() and (ship.data.burns or ship.is_sinking()):
			_set_burning(node, ship.data)
		var bob := sin(Sim.world.time * 0.7 + ship.id) * 0.3
		node.position = to_3d(ship.pos, bob - ship.sink * 30.0 - ship.depth)
		node.rotation = Vector3(ship.sink * 0.35, -deg_to_rad(ship.heading), ship.sink * 0.5 + sin(Sim.world.time * 0.5 + ship.id) * 0.02)
	for id: int in _ships.keys():
		if not seen.has(id):
			_ships[id].queue_free()
			_ships.erase(id)


## The ocean shader draws the nearest ships' wakes.
func _feed_wakes() -> void:
	var data := PackedVector4Array()
	var lens := PackedFloat32Array()
	var near := Sim.world.ships.filter(func(s: ShipState) -> bool: return not s.submerged())
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


## The ocean shader dulls and pocks the sea under each squall.
func _feed_squalls(c: Conditions) -> void:
	var data := PackedVector4Array()
	for s: Array in c.squalls.slice(0, 8):
		data.append(Vector4(s[0], -float(s[1]), s[2], Conditions.squall_strength(s)))
	var count := data.size()
	data.resize(8)
	for m: ShaderMaterial in [_ocean_near.material_override, _ocean_far.material_override]:
		m.set_shader_parameter("squalls", data)
		m.set_shader_parameter("squall_count", count)


## Night: a dark blue sky, a dim cold moon, black water with silver foam. Sea state sets the
## height of the waves. Under a squall: a low grey sky, the sun gone, a rougher sea and rain
## fog that closes the horizon in to a km or two.
func _apply_conditions(c: Conditions) -> void:
	var rain := snappedf(_weather.rain_here, 0.05)
	var key := "%s/%d/%.2f" % [c.night, c.sea_state, rain]
	if key == _look:
		return
	_look = key
	var grey := Color("#1A1F26") if c.night else Color("#6F7A84")
	_sky.sky_top_color = (Color("#0B1426") if c.night else Color("#3F7FBF")).lerp(grey * 0.8, rain)
	_sky.sky_horizon_color = (Color("#22324A") if c.night else Color("#BFD8E8")).lerp(grey, rain)
	_sky.ground_horizon_color = _sky.sky_horizon_color
	_sky.ground_bottom_color = Color("#050A12") if c.night else Color("#1F4E79")
	_sky.night = c.night and rain < 0.5
	_sky.clouds = lerpf([0.3, 0.5, 0.8][c.sea_state], 1.0, rain) # calm and clear .. rough and overcast
	_sun.light_energy = (0.25 if c.night else 1.2) * lerpf(1.0, 0.35, rain)
	_sun.light_color = Color("#9DB4D8") if c.night else Color.WHITE
	if not _under:
		_env.ambient_light_color = Color("#2A3A55") if c.night else Color("#8FA8BF").lerp(Color("#8A939B"), rain)
		_env.ambient_light_energy = 0.35 if c.night else 0.55
		_env.fog_light_color = _sky.sky_horizon_color
		_env.fog_density = lerpf(0.00002, 0.0011, rain)
		_env.fog_sky_affect = rain * 0.9 # the horizon closes in grey
	var m := _ocean_near.material_override as ShaderMaterial
	m.set_shader_parameter("amplitude", lerpf([0.3, 0.5, 0.9][c.sea_state], [0.6, 0.9, 1.2][c.sea_state], rain))
	m.set_shader_parameter("horizon_color", Color(0.12, 0.17, 0.26) if c.night else Color(0.55, 0.70, 0.82))
	m.set_shader_parameter("shallow_color", Color(0.02, 0.08, 0.12) if c.night else Color(0.05, 0.44, 0.50))
	m.set_shader_parameter("crest_color", Color(0.05, 0.16, 0.2) if c.night else Color(0.25, 0.85, 0.80))


## Under the surface: realistically dark (Blaney: "the ocean is very dark", things shouldn't show
## through the fog before they should): a few tens of metres of murky blue in open water, black
## deeper; shallow water by an island (`shore`) lets the light down, clear turquoise again.
## `depth` is the eye's depth in metres (0 = above water).
func _underwater(depth: float) -> void:
	if depth <= 0.0:
		if _under:
			_under = false
			_look = "" # puts the sky and fog back
			_env.fog_density = 0.00002
			_env.fog_sky_affect = 0.0
			_apply_conditions(Sim.world.conditions)
			camera.far = 30000.0
		return
	_under = true
	paint_water(_env, _sky, depth, Sim.world.conditions.night)
	camera.far = see_under(depth)


## How far an eye `depth` m down can see anything at all: past this the fog is solid, so
## nothing further is drawn (saves the cameras drawing what can't be seen).
static func see_under(depth: float) -> float:
	return clampf(5.0 / water_fog(depth, shore), 60.0, 400.0)


## The water's fog density at `depth`: thick in open water, thinner by a shore, thicker deeper.
static func water_fog(depth: float, by_shore: float) -> float:
	var open := 0.05 + 0.03 * clampf((depth - 40.0) / 200.0, 0.0, 1.0) # gone in ~60 m, ~40 m deep down
	return lerpf(open, 0.022, by_shore) # ~150 m of clear shallow water


## How much light reaches `depth` m (1 at the surface): fast in open water, slow by a shore.
static func water_light(depth: float, by_shore: float, night: bool) -> float:
	var l := exp(-depth / lerpf(28.0, 70.0, by_shore))
	return l * (0.18 if night else 1.0)


## Host or client: how shallow the water is round the boat (0 open .. 1 a shallow shelf),
## eased so the light changes smoothly as she comes in to an island.
func _update_shore(sub: SubState, delta: float) -> void:
	if sub.pos.distance_to(_shore_at) > 25.0:
		_shore_at = sub.pos
		var f := Sim.world.seabed.floor_depth(sub.pos)
		set_meta("shore_want", clampf((90.0 - f) / 60.0, 0.0, 1.0)) # under 30 m of water: full shallows; 90 m+: open ocean
	shore = move_toward(shore, float(get_meta("shore_want", 0.0)), delta * 0.25)


func environment() -> Environment:
	return _env


## Sets `env` and its `sky` up for an eye `depth` metres under the surface (the periscope's,
## a camera's or a porthole's own environment). The ambient light falls with the light let
## down, so an unlit thing out in the fog is as dark as the water round it and stays hidden;
## our floodlights and anything glowing still show.
static func paint_water(env: Environment, sky: ToonSky, depth: float, night: bool) -> void:
	var light := water_light(depth, shore, night)
	var lit := Color("#2FB3C4").lerp(Color("#0E5A72"), 1.0 - shore) # shallows turquoise, open sea a deep blue
	var mid := Color("#01060B").lerp(lit, clampf(light * 1.15, 0.0, 1.0))
	sky.sky_top_color = Color("#020A12").lerp(Color("#B4F2F2").lerp(Color("#4FA9C4"), 1.0 - shore), light)
	sky.sky_horizon_color = mid
	sky.ground_horizon_color = mid
	sky.ground_bottom_color = mid # below the horizon the fog and the water are one colour: nothing stands out against it
	sky.clouds = 0.0
	env.fog_enabled = true
	env.fog_light_color = mid
	env.fog_light_energy = 1.0
	env.fog_density = water_fog(depth, shore)
	env.fog_sky_affect = 0.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = mid.lerp(Color("#5E8FA8"), 0.35)
	env.ambient_light_energy = lerpf(0.04, 0.55, light)


func _sync_planes() -> void:
	var seen := {}
	for p in Sim.world.planes:
		seen[p.id] = true
		var node: Node3D = _planes.get(p.id)
		if node == null:
			node = ShipModels.plane(Sim.world.sub.data.nuclear)
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
		life.append(Vector2(0.0 if tr.ended < 0.0 else now - tr.ended, Sim.world.torpedo_speed))
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
