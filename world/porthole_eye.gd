class_name PortholeEye
extends Node
## A second camera in the ocean world for the portholes. Each frame it finds the porthole the
## local player is nearest and looking at, puts the camera on the hull just outside it,
## looking the way the player looks through it, and shows that view in the glass. It renders
## nothing while no porthole is in view.

const NEAR := 5.0 ## metres: further than this a porthole is just dark glass
const DECK_ABOVE_KEEL := 1.5 ## the interior deck's height over the keel

var game: Game
var viewport: SubViewport
var camera: Camera3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _shown: Porthole


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.world_3d = game.exterior.viewport.find_world_3d() # the ocean the periscope sees
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	camera = Camera3D.new()
	camera.near = 0.3
	camera.far = 4000.0
	camera.current = true
	viewport.add_child(camera)
	_sky = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky
	_env = game.exterior.environment().duplicate()
	_env.sky = sky


func _process(_delta: float) -> void:
	var target := _pick()
	if target != _shown:
		if _shown != null:
			_shown.set_view(null)
		_shown = target
		if _shown != null:
			_shown.set_view(viewport.get_texture())
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _shown != null else SubViewport.UPDATE_DISABLED
	if _shown != null:
		_place(_shown)


func _pick() -> Porthole:
	var me := game.local_player
	if me == null or game.interior == null or Sim.world == null or game.menu_open():
		return null
	var eye := me.camera.global_position
	var look := -me.camera.global_basis.z
	var best: Porthole = null
	var best_d := NEAR
	for p: Porthole in game.interior.portholes:
		var to := p.global_position - eye
		var d := to.length()
		if d < best_d and look.dot(to / d) > 0.35:
			best_d = d
			best = p
	return best


## The camera on the hull outside `p`, looking along the line from the player's eye through it.
func _place(p: Porthole) -> void:
	var sub := Sim.world.sub
	var rad := deg_to_rad(sub.heading)
	var fwd := Vector3(sin(rad), 0.0, -cos(rad))
	var stbd := Vector3(cos(rad), 0.0, sin(rad))
	# Interior axes in the ocean world: +X starboard, +Y up, +Z aft.
	var to_world := Basis(stbd, Vector3.UP, -fwd)
	var mid: float = (game.interior.compartments[0].z0 + game.interior.compartments[-1].z1) * 0.5
	var local := p.global_position - Vector3(0.0, 0.0, mid)
	var origin := ExteriorWorld.to_3d(sub.pos, DECK_ABOVE_KEEL - sub.depth)
	camera.global_position = origin + to_world * (local + Vector3(p.side * 0.4, 0.0, 0.0))
	var eye := game.local_player.camera.global_position
	var dir := to_world * (p.global_position - eye).normalized()
	camera.look_at(camera.global_position + dir, Vector3.UP)
	var dist := maxf(eye.distance_to(p.global_position), 0.3)
	camera.fov = clampf(rad_to_deg(2.0 * atan(Porthole.RADIUS / dist)) * 2.2, 35.0, 95.0)
	var depth := -camera.global_position.y
	if depth > 0.0:
		ExteriorWorld.paint_water(_env, _sky, depth, Sim.world.conditions.night)
		camera.environment = _env
	else:
		camera.environment = null
