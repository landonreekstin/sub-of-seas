class_name Player
extends CharacterBody3D
## A crew member. Owner-authoritative movement, synced to everyone with a
## MultiplayerSynchronizer. Walks, climbs ladders, carries the interaction ray,
## and hands input to a station while manning one.

const SPEED := 3.2
const GRAVITY := 12.0
const JUMP := 3.2
const LOOK_SENSITIVITY := 0.0025
const EYE_HEIGHT := 1.6
const REACH := 2.2

var peer_id := 1
var station: Station = null
var requested_station := ""
var climbing := false
var held_tool := "" ## from crew state (host-owned)
var trauma := 0.0 ## camera shake, 0..1, decays

var _hand: Node3D ## the held tool, in front of the camera (local) or in the hands (others)
var _tool_fx: CPUParticles3D ## spray or sparks while the tool is working
var _work_timer := 0.0
var _tool_sound: AudioStreamPlayer3D ## the torch's hiss or the extinguisher's rush while working

var head: Node3D
var camera: Camera3D
var ray: RayCast3D
var body: Node3D ## the sailor below the head: torso, arms and legs that swing as he walks
var _limbs := {} ## "arm_l", "arm_r", "leg_l", "leg_r" -> pivot Node3D
var _shirt_parts: Array[MeshInstance3D] = []
var _hat: Node3D
var _look := {}
var _last_pos := Vector3.ZERO
var _stride := 0.0
var name_tag: Label3D
var _camera_tween: Tween


static func create(id: int, spawn_pos: Vector3) -> Player:
	var p := Player.new()
	p.peer_id = id
	p.name = str(id)
	p.position = spawn_pos
	p._build()
	p.set_multiplayer_authority(id)
	return p


func _build() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.26
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.875
	add_child(shape)

	_build_sailor(Color.from_hsv(fposmod(peer_id * 0.618034, 1.0), 0.45, 0.85))

	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE_HEIGHT
	add_child(head)
	# A big round head under a white "Dixie cup" sailor's hat; dot eyes, a nose.
	var face := Build.sphere(head, 0.24, Vector3(0, -0.05, 0), Color("#F0C9A0"))
	_hat = _make_hat(face, "dixie")
	Build.box(face, Vector3(0.05, 0.07, 0.02), Vector3(-0.08, 0.03, -0.23), Color.BLACK, false)
	Build.box(face, Vector3(0.05, 0.07, 0.02), Vector3(0.08, 0.03, -0.23), Color.BLACK, false)
	Build.sphere(face, 0.045, Vector3(0, -0.04, -0.24), Color("#E3B48C"))

	camera = Camera3D.new()
	camera.fov = 75.0
	camera.near = 0.05
	head.add_child(camera)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -REACH)
	ray.collision_mask = 1
	ray.collide_with_areas = true
	ray.add_exception(self)
	camera.add_child(ray)

	name_tag = Label3D.new()
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.position.y = 2.05
	name_tag.font_size = 32
	name_tag.pixel_size = 0.004
	name_tag.no_depth_test = false
	add_child(name_tag)

	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop: String in [".:position", ".:rotation", "Head:rotation"]:
		var path := NodePath(prop)
		cfg.add_property(path)
		cfg.property_set_spawn(path, true)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


## Peak-like sailor: chunky chambray-blue shirt in the crewman's colour, navy dungarees,
## black boots, arms and legs on pivots so a walk can swing them.
func _build_sailor(shirt: Color) -> void:
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	var torso := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.27
	cm.height = 0.8
	torso.mesh = cm
	torso.material_override = Build.mat(shirt)
	_shirt_parts.append(torso)
	torso.position.y = 1.08
	body.add_child(torso)
	Build.box(body, Vector3(0.5, 0.12, 0.34), Vector3(0, 0.74, 0), Color("#2B3A55"), false) # belt line
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.13, 0.78, 0)
		body.add_child(leg)
		Build.cyl(leg, 0.11, 0.62, Vector3(0, -0.34, 0), Color("#2B3A55"))
		Build.box(leg, Vector3(0.18, 0.12, 0.28), Vector3(0, -0.72, -0.05), Color("#1E1E20"), false)
		_limbs["leg_l" if side < 0.0 else "leg_r"] = leg
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.34, 1.36, 0)
		body.add_child(arm)
		_shirt_parts.append(Build.cyl(arm, 0.08, 0.55, Vector3(0, -0.28, 0), shirt))
		Build.sphere(arm, 0.08, Vector3(0, -0.6, 0), Color("#F0C9A0"))
		_limbs["arm_l" if side < 0.0 else "arm_r"] = arm


## The look from the player's profile: hat and shirt colour (crew state, so all agree).
func set_looks(look: Dictionary) -> void:
	if look == _look or look.is_empty():
		return
	_look = look
	var hue: float = look.get("hue", -1.0)
	var shirt := Color.from_hsv(fposmod(peer_id * 0.618034, 1.0) if hue < 0.0 else hue, 0.45, 0.85)
	for m in _shirt_parts:
		m.material_override = Build.mat(shirt)
	var face: Node3D = _hat.get_parent()
	_hat.queue_free()
	_hat = _make_hat(face, look.get("hat", "dixie"))
	if is_local():
		_hat.visible = false


static func _make_hat(face: Node3D, kind: String) -> Node3D:
	var h := Node3D.new()
	face.add_child(h)
	var white := Color("#F2F0E8")
	var navy := Color("#2B3A55")
	match kind:
		"watch": # navy knit cap
			Build.sphere(h, 0.23, Vector3(0, 0.12, 0), navy)
			Build.cyl(h, 0.235, 0.08, Vector3(0, 0.1, 0), Color("#24304A"))
		"ball":
			Build.sphere(h, 0.22, Vector3(0, 0.13, 0), navy)
			Build.box(h, Vector3(0.26, 0.03, 0.2), Vector3(0, 0.12, -0.24), navy, false)
		"officer", "skipper": # peaked cap, white top; the skipper's is weathered grey
			var top := Color("#C9C3B0") if kind == "skipper" else white
			Build.cyl(h, 0.27, 0.1, Vector3(0, 0.25, 0), top)
			Build.cyl(h, 0.22, 0.1, Vector3(0, 0.17, 0), Color("#1E1E20"))
			Build.box(h, Vector3(0.28, 0.025, 0.14), Vector3(0, 0.13, -0.24), Color("#1E1E20"), false)
			Build.box(h, Vector3(0.1, 0.06, 0.02), Vector3(0, 0.19, -0.22), Color("#C9A04A"), false) # badge
		_: # white Dixie cup
			Build.cyl(h, 0.2, 0.14, Vector3(0, 0.22, 0), white)
			var brim := Build.cyl(h, 0.25, 0.06, Vector3(0, 0.17, 0), white)
			brim.rotation.x = 0.12
	return h


## Procedural walk for everyone else's sailor: legs and arms swing with ground speed, arms
## reach forward while manning a station.
func _animate_body(delta: float) -> void:
	var v := (global_position - _last_pos) / maxf(delta, 0.001)
	_last_pos = global_position
	var speed := Vector2(v.x, v.z).length()
	_stride += delta * speed * 3.2
	var swing := sin(_stride) * clampf(speed / SPEED, 0.0, 1.0) * 0.6
	var at_station: bool = Game.instance.crew.get("stations", {}).values().has(peer_id)
	_limbs.leg_l.rotation.x = swing
	_limbs.leg_r.rotation.x = -swing
	_limbs.arm_l.rotation.x = -1.1 if at_station else -swing * 0.8
	_limbs.arm_r.rotation.x = -1.1 if at_station else swing * 0.8
	body.position.y = absf(sin(_stride)) * 0.04 * clampf(speed / SPEED, 0.0, 1.0)


func is_local() -> bool:
	return is_multiplayer_authority()


func _ready() -> void:
	if is_local():
		camera.current = true
		for m: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		head.get_child(0).visible = false
		name_tag.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Game.instance.local_player = self
		if Net.debug_spawn != null:
			global_position = Net.debug_spawn
		rotation.y = -deg_to_rad(Net.debug_look)
		if Net.debug_station != "":
			_man_on_spawn.call_deferred()


## Testing aid (--station): ask for the station once the crew state has arrived.
func _man_on_spawn() -> void:
	await get_tree().create_timer(1.5).timeout
	var s: Station = Game.instance.interior.stations.get(Net.debug_station)
	if s != null:
		request_station(s)


func set_display_name(n: String) -> void:
	name_tag.text = n


## Shows the tool the host says this crewman carries.
func set_tool(kind: String) -> void:
	if kind == held_tool:
		return
	held_tool = kind
	if _hand != null:
		_hand.queue_free()
		_hand = null
		_tool_sound = null
	if kind == "":
		return
	_hand = Tools.model(kind)
	_tool_fx = null
	if kind == "extinguisher":
		_tool_fx = Build.particles(_hand, Color(0.95, 0.97, 1.0, 0.7), 30, 0.5, Vector3.FORWARD, 3.0, 10.0, Vector3(0, -1, 0), 0.08)
		_tool_fx.position = Vector3(0, 0.2, -0.12)
	elif kind == "torch":
		_tool_fx = Build.particles(_hand, Color(0.6, 0.8, 1.0), 30, 0.3, Vector3.FORWARD, 1.5, 60.0, Vector3(0, -6, 0), 0.03)
		_tool_fx.position = Vector3(0, 0.02, -0.34)
	if _tool_fx != null:
		_tool_fx.emitting = false
	if is_local():
		_hand.position = Vector3(0.28, -0.26, -0.5)
		camera.add_child(_hand)
	else:
		_hand.position = Vector3(0.3, 1.0, -0.3)
		add_child(_hand)


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func is_knocked_out() -> bool:
	return Game.instance.crew.get("knocked", {}).has(peer_id)


## How bad the air is where you stand (0..1), and the smoke there.
func breathing() -> Vector2:
	if Sim.world == null:
		return Vector2.ZERO
	var c := Sim.world.hull.comp_at(global_position.z)
	var smoke: float = Sim.world.air.smoke[c] if c < Sim.world.air.smoke.size() else 0.0
	return Vector2(Sim.world.air.badness_in(c), smoke)


func _unhandled_input(event: InputEvent) -> void:
	if not is_local() or is_knocked_out():
		return
	if station != null:
		if event.is_action_pressed("leave_station"):
			leave_station()
		elif event.is_action_pressed("next_station"):
			var next := Game.instance.interior.next_in_cluster(station)
			if next != null:
				request_station(next)
		elif not station.broken:
			station.station_input(event)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * LOOK_SENSITIVITY)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * LOOK_SENSITIVITY, -1.45, 1.45)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("leave_station"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("interact") and not climbing:
		var target := _interact_target()
		if target != null:
			target.interact(self)
	elif event.is_action_pressed("drop_tool") and held_tool != "":
		Game.instance.rq_tool.rpc_id(1, "")
	elif event.is_action_pressed("use_tool") and held_tool == "pump" and is_on_floor():
		_place_pump()


func _physics_process(delta: float) -> void:
	if not is_local() or climbing:
		return
	if station != null:
		velocity = Vector3.ZERO
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if is_knocked_out():
		input = Vector2.ZERO
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	# Wading through flood water is slow.
	var wade := 0.0
	if Game.instance.interior != null:
		wade = clampf(Game.instance.interior.damage.water_height_at(position.z) - position.y, 0.0, 1.2) / 1.2
	var speed := SPEED * lerpf(1.0, 0.4, wade) * lerpf(1.0, 0.55, breathing().x) # bad air makes your legs heavy
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()


func _process(delta: float) -> void:
	if not is_local():
		_animate_body(delta)
		return
	_apply_hull_tilt()
	_apply_shake(delta)
	var hud := Game.instance.hud
	var air := breathing()
	hud.set_air(air.x, air.y, is_knocked_out())
	if is_knocked_out():
		hud.set_prompt("")
		return
	if station != null or climbing:
		hud.set_prompt("THIS STATION IS BROKEN — get a wrench on it" if station != null and station.broken else "")
		return
	var target := _interact_target()
	var prompt: String = target.get_prompt(self) if target != null else ""
	if prompt == "" and held_tool != "":
		prompt = "%s  —  [G] put it down" % Tools.display_name(held_tool)
	hud.set_prompt(prompt)
	_use_tool(target, delta)


## Holding LMB with the right tool on a target sends work to the host a few times a second.
func _use_tool(target: Node, delta: float) -> void:
	var id := ""
	if held_tool not in ["", "pump"] and Input.is_action_pressed("use_tool") and target != null and target.has_method("tool_target"):
		id = target.tool_target(held_tool)
	if _tool_fx != null:
		_tool_fx.emitting = id != ""
	if held_tool in ["torch", "extinguisher"]:
		if id != "" and _tool_sound == null:
			_tool_sound = Sfx.loop_at(_hand, "torch_loop", Vector3.ZERO, -2.0 if held_tool == "torch" else 2.0)
			_tool_sound.pitch_scale = 1.0 if held_tool == "torch" else 0.6
		elif id == "" and _tool_sound != null:
			_tool_sound.queue_free()
			_tool_sound = null
	if id == "":
		_work_timer = 0.0
		return
	_work_timer += delta
	if _work_timer >= 0.2:
		Game.instance.rq_work.rpc_id(1, held_tool, id, _work_timer)
		_work_timer = 0.0
	if _hand != null: # a little shake of the working tool
		_hand.position = Vector3(0.28, -0.26, -0.5) + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.006


## The pump goes on the deck just in front of your feet; no aiming needed.
func _place_pump() -> void:
	var fwd := -global_basis.z
	fwd.y = 0.0
	var spot := global_position + fwd.normalized() * 0.6
	spot.x = clampf(spot.x, -1.5, 1.5) # stay clear of the curved hull sides
	Game.instance.rq_place_pump.rpc_id(1, spot)


## Trauma-based shake: the offset grows with trauma squared, so small knocks stay small.
func _apply_shake(delta: float) -> void:
	trauma = maxf(0.0, trauma - delta * 0.9)
	var s := trauma * trauma
	var t := Time.get_ticks_msec() * 0.001
	camera.h_offset = s * 0.12 * sin(t * 37.0) * cos(t * 13.0)
	camera.v_offset = s * 0.12 * sin(t * 29.0 + 1.3)


## The interior never moves; the sub's pitch and roll are shown by tilting the view.
func _apply_hull_tilt() -> void:
	if Sim.world == null or station != null:
		return
	var sub := Sim.world.sub
	var roll := clampf(-sub.turn_rate * 1.2, -4.0, 4.0)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(-sub.pitch)) * Basis(Vector3.BACK, deg_to_rad(roll))
	var hb := head.global_basis.orthonormalized()
	camera.basis = hb.inverse() * tilt * hb


func _interact_target() -> Node:
	if not ray.is_colliding():
		return null
	var n: Node = ray.get_collider()
	while n != null:
		if n.has_method("interact") and n.has_method("get_prompt"):
			return n
		n = n.get_parent()
	return null


# --- Stations --------------------------------------------------------------

func request_station(s: Station) -> void:
	requested_station = s.station_id
	Game.instance.rq_station_enter.rpc_id(1, s.station_id)


## Called by Game whenever crew state arrives, with the station the host says we hold.
func sync_station(held_id: String) -> void:
	if held_id != "" and held_id == requested_station:
		if station == null or station.station_id != held_id:
			_enter_view(Game.instance.interior.stations[held_id])
	elif station != null and held_id != station.station_id:
		_exit_view()


func leave_station() -> void:
	requested_station = ""
	_exit_view()
	Game.instance.rq_station_leave.rpc_id(1)


func _enter_view(s: Station) -> void:
	if station != null:
		station.on_leave()
	station = s
	if not camera.top_level:
		var from := camera.global_transform
		camera.top_level = true
		camera.global_transform = from
	_tween_camera(s.get_view_transform())
	Game.instance.hud.show_overlay(s.make_overlay())
	s.on_enter()


func _exit_view() -> void:
	if station == null:
		return
	station.on_leave()
	station = null
	Game.instance.hud.show_overlay(null)
	_tween_camera(head.global_transform).finished.connect(func() -> void:
		if station == null:
			camera.top_level = false
			camera.transform = Transform3D.IDENTITY)


func _tween_camera(to: Transform3D) -> Tween:
	if _camera_tween != null:
		_camera_tween.kill()
	_camera_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(camera, "global_transform", to, 0.35)
	return _camera_tween


# --- Ladders ---------------------------------------------------------------

## Climb along a list of global points (a ladder's path). Movement is a tween, synced
## like any other movement.
func climb(points: Array[Vector3]) -> void:
	climbing = true
	velocity = Vector3.ZERO
	var tw := create_tween()
	var from := global_position
	for p in points:
		tw.tween_property(self, "global_position", p, maxf(0.2, from.distance_to(p) / 2.0))
		from = p
	tw.finished.connect(func() -> void: climbing = false)
