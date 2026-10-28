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

var head: Node3D
var camera: Camera3D
var ray: RayCast3D
var body_mesh: MeshInstance3D
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

	var color := Color.from_hsv(fposmod(peer_id * 0.618034, 1.0), 0.45, 0.85)
	body_mesh = MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.3
	cm.height = 1.4
	body_mesh.mesh = cm
	body_mesh.material_override = Build.mat(color)
	body_mesh.position.y = 0.7
	add_child(body_mesh)

	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE_HEIGHT
	add_child(head)
	var face := Build.sphere(head, 0.24, Vector3(0, -0.05, 0), Color("#F0C9A0"))
	Build.box(face, Vector3(0.5, 0.06, 0.5), Vector3(0, 0.2, 0), Color("#2B3A55"), false) # cap brim
	Build.cyl(face, 0.2, 0.16, Vector3(0, 0.27, 0), Color("#2B3A55")) # cap
	Build.box(face, Vector3(0.05, 0.07, 0.02), Vector3(-0.08, 0.03, -0.23), Color.BLACK, false)
	Build.box(face, Vector3(0.05, 0.07, 0.02), Vector3(0.08, 0.03, -0.23), Color.BLACK, false)

	camera = Camera3D.new()
	camera.fov = 75.0
	camera.near = 0.05
	head.add_child(camera)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -REACH)
	ray.collision_mask = 1
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


func is_local() -> bool:
	return is_multiplayer_authority()


func _ready() -> void:
	if is_local():
		camera.current = true
		body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		head.get_child(0).visible = false
		name_tag.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Game.instance.local_player = self
		if Net.debug_spawn != null:
			global_position = Net.debug_spawn


func set_display_name(n: String) -> void:
	name_tag.text = n


func _unhandled_input(event: InputEvent) -> void:
	if not is_local():
		return
	if station != null:
		if event.is_action_pressed("leave_station"):
			leave_station()
		elif event.is_action_pressed("next_station"):
			var next := Game.instance.interior.next_in_cluster(station)
			if next != null:
				request_station(next)
		else:
			station.station_input(event)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * LOOK_SENSITIVITY)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * LOOK_SENSITIVITY, -1.45, 1.45)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("leave_station"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("interact") and not climbing:
		var target := _interact_target()
		if target != null:
			target.interact(self)


func _physics_process(delta: float) -> void:
	if not is_local() or climbing:
		return
	if station != null:
		velocity = Vector3.ZERO
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()


func _process(_delta: float) -> void:
	if not is_local():
		return
	_apply_hull_tilt()
	var hud := Game.instance.hud
	if station != null or climbing:
		hud.set_prompt("")
		return
	var target := _interact_target()
	hud.set_prompt(target.get_prompt(self) if target != null else "")


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
