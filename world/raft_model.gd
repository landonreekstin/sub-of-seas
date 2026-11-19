class_name RaftModel
extends Node3D
## A life raft as seen on the sea (Raft): a yellow rubber WWII-style four-man raft (Blaney),
## an oval tube round a sagging floor, a patch of grey lifelines, paddles, and the funny bit:
## a red rocket that lives in a canvas compartment on the starboard tube and, fitted to the
## stern, the driver steers by its tiller like a small motor boat. Bow is -z, waterline y 0.

const LENGTH := 2.8
const BEAM := 1.6
const TUBE := 0.24 ## the tube's radius
const YELLOW := Color("#F2C230")
const YELLOW_DARK := Color("#C99A1E")
## Where each seat's man sits (raft space, his hips): the driver aft to starboard of the engine,
## one in the bow, one each side amidships.
const SEATS: Array[Vector3] = [Vector3(0.42, 0.2, 0.95), Vector3(0.0, 0.2, -0.45), Vector3(-0.5, 0.2, 0.35), Vector3(0.5, 0.2, 0.15)]
const SEAT_FACING: Array[float] = [0.0, 0.0, 0.0, 0.0] ## yaw each one faces (all forward)
const EYE := 0.82 ## his eye over his hips, sitting

var _rocket: Node3D
var _pouch: Node3D
var _flame: MeshInstance3D
var _tiller: Node3D
var _paddles: Array[Node3D] = []


func _ready() -> void:
	# The tube: a torus pulled out into an oval, and its seams.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = BEAM * 0.5 - TUBE * 2.0
	torus.outer_radius = BEAM * 0.5
	torus.rings = 20
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = Build.mat(YELLOW)
	ring.scale = Vector3(1.0, 1.0, LENGTH / BEAM)
	ring.position.y = TUBE * 0.9
	add_child(ring)
	var seam := MeshInstance3D.new()
	var thin := TorusMesh.new()
	thin.inner_radius = BEAM * 0.5 - 0.02
	thin.outer_radius = BEAM * 0.5 + 0.015
	thin.rings = 20
	thin.ring_segments = 4
	seam.mesh = thin
	seam.material_override = Build.mat(YELLOW_DARK)
	seam.scale = ring.scale
	seam.position.y = TUBE * 0.9
	add_child(seam)
	# The floor, sagging just under the water.
	var floor_mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = BEAM * 0.5 - TUBE
	disc.bottom_radius = BEAM * 0.5 - TUBE * 1.3
	disc.height = 0.08
	disc.radial_segments = 16
	floor_mesh.mesh = disc
	floor_mesh.material_override = Build.mat(YELLOW_DARK)
	floor_mesh.scale = Vector3(1.0, 1.0, LENGTH / BEAM)
	floor_mesh.position.y = 0.04
	add_child(floor_mesh)
	# The grey lifeline looped round the outside.
	for i in 10:
		var a := TAU * (i + 0.5) / 10.0
		var p := Vector3(cos(a) * (BEAM * 0.5 + 0.03), TUBE * 0.6, sin(a) * (LENGTH * 0.5 + 0.03))
		Build.sphere(self, 0.035, p, Color("#8A8F94"))
	# Two paddles lashed inside the tube, port side; held up by a paddler while he paddles.
	for side in [-1.0, 1.0]:
		var paddle := Node3D.new()
		var seat := SEATS[2 if side < 0.0 else 3]
		paddle.position = Vector3(side * 0.8, 0.6, seat.z - 0.1) # in his hands, out over the side
		add_child(paddle)
		Build.cyl(paddle, 0.025, 1.3, Vector3.ZERO, Color("#B08850"), Vector3.FORWARD)
		Build.box(paddle, Vector3(0.18, 0.03, 0.34), Vector3(0, 0, -0.75), Color("#B08850"), false)
		paddle.visible = false
		_paddles.append(paddle)
	# The rocket's compartment: a canvas pouch strapped to the starboard tube, aft.
	_pouch = Node3D.new()
	_pouch.position = Vector3(BEAM * 0.5 - 0.05, TUBE * 1.6, 0.55)
	add_child(_pouch)
	Build.box(_pouch, Vector3(0.22, 0.24, 0.62), Vector3.ZERO, Color("#7A7550"), false)
	Build.box(_pouch, Vector3(0.24, 0.05, 0.64), Vector3(0, 0.13, 0), Color("#5E5A3C"), false)
	Build.label(_pouch, "ROCKET", Vector3(0.125, 0.0, 0.0), 16, Color("#E04030")).rotation.y = PI / 2.0
	# The rocket on the stern: a fat red body with a white nose and fins, on a bracket, its tiller
	# coming forward to the driver's hand.
	_rocket = Node3D.new()
	_rocket.position = Vector3(0.0, TUBE * 1.9, LENGTH * 0.5 + 0.05)
	add_child(_rocket)
	Build.box(_rocket, Vector3(0.3, 0.3, 0.12), Vector3(0, -0.12, -0.12), Color("#55585C"), false)
	Build.cyl(_rocket, 0.13, 0.75, Vector3(0, 0.1, 0.15), Color("#D8352A"), Vector3.FORWARD)
	Build.lathe(_rocket, [Vector2(0, 0), Vector2(0.13, 0), Vector2(0.09, 0.14), Vector2(0, 0.26)], Vector3(0, 0.1, -0.22), Color("#F2EDE0"), Vector3.FORWARD)
	Build.lathe(_rocket, [Vector2(0.06, 0), Vector2(0.11, 0), Vector2(0.14, 0.16), Vector2(0.1, 0.16)], Vector3(0, 0.1, 0.52), Color("#3A3C40"), Vector3.BACK)
	for k in 4:
		var fin := Build.box(_rocket, Vector3(0.025, 0.2, 0.22), Vector3(0, 0.1, 0.42), Color("#F2EDE0"), false)
		fin.rotation.z = k * PI / 2.0
		fin.position += Vector3(sin(k * PI / 2.0), cos(k * PI / 2.0), 0) * 0.15
	Build.box(_rocket, Vector3(0.26, 0.02, 0.05), Vector3(0, 0.235, 0.15), Color("#F2EDE0"), false) # a white band
	_tiller = Node3D.new()
	_tiller.position = Vector3(0.0, 0.05, -0.15)
	_rocket.add_child(_tiller)
	Build.cyl(_tiller, 0.022, 0.6, Vector3(0.0, 0.0, -0.3), Color("#2E2F33"), Vector3.FORWARD)
	Build.sphere(_tiller, 0.04, Vector3(0, 0, -0.6), Color("#1A1A1A"))
	_flame = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.1
	cone.bottom_radius = 0.0
	cone.height = 1.0
	cone.radial_segments = 8
	_flame.mesh = cone
	_flame.material_override = Build.mat(Color("#FFB040"), 3.0)
	_flame.rotation.x = -PI / 2.0
	_flame.position = Vector3(0, 0.1, 1.2)
	_rocket.add_child(_flame)


## Shows her as she is: the rocket fitted or in its pouch, its flame with the throttle, the
## tiller over, paddles out for the seats that paddle.
func show_state(r: Raft) -> void:
	_rocket.visible = r.rocket
	_pouch.visible = not r.rocket
	var burn := clampf(r.throttle, 0.0, 1.0) if r.rocket else 0.0
	_flame.visible = burn > 0.02
	_flame.scale = Vector3(1.0 + burn * 0.5, 0.5 + burn * 2.5 * randf_range(0.8, 1.15), 1.0 + burn * 0.5)
	_flame.position.z = 0.75 + _flame.scale.y * 0.5
	_tiller.rotation.y = -r.steer * 0.6
	var t := Time.get_ticks_msec() / 1000.0
	for i in _paddles.size():
		_paddles[i].visible = not r.rocket and (r.crew[2 + i] != 0)
		var pulling := absf(r.speed) > 0.3
		_paddles[i].rotation.x = -0.9 + (sin(t * 4.5 + i * PI) * 0.35 if pulling else 0.0) # the blade in the water, stroking


## The eye of whoever sits in `seat`, in raft space, looking `yaw` / `pitch` (radians) off ahead.
static func seat_eye(seat: int, yaw: float, pitch: float) -> Transform3D:
	var s := SEATS[clampi(seat, 0, SEATS.size() - 1)]
	return Transform3D(Basis.from_euler(Vector3(pitch, SEAT_FACING[seat] + yaw, 0.0), EULER_ORDER_YXZ), s + Vector3(0, EYE, 0))


## Where the raft sits on the sea this frame: on the waves under her, pitched and rolled to
## their slope, in the air while she skips; `world` her exterior position.
static func sea_transform(r: Raft) -> Transform3D:
	var at := ExteriorWorld.to_3d(r.pos)
	var h := deg_to_rad(r.heading)
	var fwd := Vector3(sin(h), 0.0, -cos(h))
	var right := Vector3(cos(h), 0.0, sin(h))
	var y := r.height()
	var pitch := 0.0
	var roll := 0.0
	if r.ground <= 0.0: # afloat: ride the waves (a little damped: she's light, but the drawn mesh is coarse)
		var t := Waves.now()
		var c := Waves.height(at.x, at.z, t)
		var f := Waves.height(at.x + fwd.x * 1.4, at.z + fwd.z * 1.4, t)
		var b := Waves.height(at.x - fwd.x * 1.4, at.z - fwd.z * 1.4, t)
		var sr := Waves.height(at.x + right.x * 0.8, at.z + right.z * 0.8, t)
		var sl := Waves.height(at.x - right.x * 0.8, at.z - right.z * 0.8, t)
		y += maxf(c, (f + b) * 0.5) if r.hop <= 0.0 else c
		pitch = atan2(f - b, 2.8)
		roll = atan2(sr - sl, 1.6)
	if r.hop > 0.0: # nose up in the air
		pitch += clampf(r.vy * 0.04, -0.25, 0.3)
	if r.rocket and r.hop <= 0.0:
		pitch += clampf(r.speed / Raft.ROCKET_TOP, 0.0, 1.0) * 0.12 # up on the plane
	var basis := Basis.from_euler(Vector3(pitch, -h, roll), EULER_ORDER_YXZ)
	return Transform3D(basis, Vector3(at.x, y, at.z))
