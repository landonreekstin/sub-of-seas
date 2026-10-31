class_name Deck
extends Node3D
## Out on deck (Blaney: "when the sub is high enough above water make it possible to get out and
## walk on the top of it"). The interior never moves, so the casing is built a second time as
## plain collision far above the boat, in our own boat's coordinates (ShipModels.own_dims: z bow
## to stern, y up from the waterline). A crewman up here walks on that; what everyone sees is
## the exterior ocean through a camera on the real model, and the crew on deck stand there as
## crewman figures. Over the side is the sea: you swim, and climb back up the rungs amidships.
## Surfaced only. While anyone is out the boat can't dive (Blaney); if she goes under anyway
## (flooding), they are sent down the hatch.

const ORIGIN := Vector3(0, 400, 0) ## where the deck's waterline sits in the interior's space
const SWIM_EYE := 0.35 ## m the eye rides above the water while swimming
const IN_WATER := -0.6 ## local feet height below which a crewman is swimming
const SEGMENTS := 48

var dims := {}
var _view: CanvasLayer
var _figures := {} ## peer id -> {node, look, last}
var _sea: AudioStreamPlayer
var _was_on := false


static func create(sub: SubClassData) -> Deck:
	var d := Deck.new()
	d.name = "Deck"
	d.dims = ShipModels.own_dims(sub)
	return d


## Is this point (interior space) out on deck or in the sea around it?
static func is_out(p: Vector3) -> bool:
	return p.y > ORIGIN.y - 40.0


static func is_swimming(p: Vector3) -> bool:
	return is_out(p) and p.y - ORIGIN.y < IN_WATER


func _ready() -> void:
	position = ORIGIN
	var l: float = dims.length
	var beam: float = dims.beam
	var fb: float = dims.deck
	# The hull: a slab per station along her length, its top the deck and its sides the hull.
	for i in SEGMENTS:
		var t := (i + 0.5) / SEGMENTS
		var w := ShipModels.hull_half(t, beam) * 2.0
		var top := ShipModels.hull_deck(t, fb)
		_solid(Vector3(maxf(w, 0.4), top + 4.5, l / SEGMENTS + 0.02), Vector3(0, (top - 4.5) * 0.5, -l * 0.5 + t * l))
	# The fairwater round the conning tower, the gun's pedestal, the ammunition lockers.
	var ct_z: float = dims.ct_z
	var ct_len: float = dims.ct_len
	var ct_h: float = dims.ct_h
	_solid(Vector3(beam * 0.32, ct_h, ct_len), Vector3(0, fb + ct_h * 0.5, ct_z))
	_solid(Vector3(beam * 0.3, ct_h, beam * 0.3), Vector3(0, fb + ct_h * 0.5, ct_z - ct_len * 0.5))
	_solid(Vector3(1.4, 1.6, 1.6), Vector3(0, fb + 0.8, dims.gun_z))
	for side in [-1.0, 1.0]:
		_solid(Vector3(0.6, 0.7, 1.4), Vector3(side * beam * 0.22, fb + 0.35, ct_z - ct_len * 0.5 - 1.5))
	# Nobody swims off over the horizon: a pen of sea round her, and a floor under it.
	var pen := Vector2(beam * 0.5 + 14.0, l * 0.5 + 14.0)
	for side in [-1.0, 1.0]:
		_solid(Vector3(1.0, 30.0, pen.y * 2.0), Vector3(side * pen.x, 5.0, 0))
		_solid(Vector3(pen.x * 2.0, 30.0, 1.0), Vector3(0, 5.0, side * pen.y))
	_solid(Vector3(pen.x * 2.0, 1.0, pen.y * 2.0), Vector3(0, -6.0, 0))
	# The hatch back down, and a ladder from the water up each side.
	var hatch := Hatch.new()
	hatch.position = Vector3(0, fb, dims.hatch_z)
	add_child(hatch)
	Build.area(hatch, Vector3(1.1, 0.5, 1.1), Vector3(0, 0.25, 0))
	var lt := (float(dims.ladder_z) + l * 0.5) / l
	var lz: float = dims.ladder_z
	for side in [-1.0, 1.0]:
		var hw := ShipModels.hull_half(lt, beam)
		var ladder := Ladder.new()
		ladder.label_up = "Climb aboard"
		ladder.label_down = "Climb down into the sea"
		add_child(ladder)
		ladder.top_y = ORIGIN.y + fb
		ladder.bottom_path = [ORIGIN + Vector3(side * (hw + 0.55), SWIM_EYE - Player.EYE_HEIGHT, lz),
			ORIGIN + Vector3(side * (hw + 0.55), fb + 0.15, lz), ORIGIN + Vector3(side * (hw - 0.7), fb + 0.05, lz)]
		Build.area(ladder, Vector3(1.2, fb + 2.0, 1.2), Vector3(side * (hw + 0.3), fb * 0.5 - 0.6, lz))


func _solid(size: Vector3, pos: Vector3) -> void:
	var body := Build.hitbox(self, size, pos)
	body.name = "DeckSolid"


## Where a crewman coming up the hatch stands (interior space), facing forward.
func hatch_spot() -> Vector3:
	return ORIGIN + Vector3(0, float(dims.deck) + 0.05, float(dims.hatch_z) - 0.9)


## Can the crew go out? Surfaced, vents shut.
static func can_go_out() -> bool:
	var sub := Sim.world.sub
	return sub.is_surfaced() and not sub.vents_open


func _process(delta: float) -> void:
	var me := Game.instance.local_player
	var on := me != null and is_out(me.global_position)
	if on != _was_on:
		_switch_view(on)
	if on:
		var ext := Game.instance.exterior
		var cam := me.camera.global_transform
		cam.origin -= ORIGIN
		ext.deck_eye = cam
		ext.deck_fov = me.camera.fov
	_sync_figures(on, delta)


## Looking at the sea from the deck: the exterior on the whole screen, under the HUD.
func _switch_view(on: bool) -> void:
	_was_on = on
	var ext := Game.instance.exterior
	ext.eye_mode = "deck" if on else "scope"
	ext.set_active(on)
	if on:
		_view = CanvasLayer.new()
		_view.layer = -1
		var tex := TextureRect.new()
		tex.texture = ext.viewport.get_texture()
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_view.add_child(tex)
		add_child(_view)
		_sea = AudioStreamPlayer.new()
		_sea.stream = Sfx.stream("sea_loop")
		_sea.bus = "Effects"
		_sea.volume_db = -8.0
		add_child(_sea)
		_sea.play()
	else:
		if _view != null:
			_view.queue_free()
		if _sea != null:
			_sea.queue_free()
		_view = null
		_sea = null


## The crew out on deck, as figures on the boat in the exterior (seen only from the deck).
func _sync_figures(on: bool, delta: float) -> void:
	var own: Node3D = Game.instance.exterior.own_boat() if on else null
	var seen := {}
	if own != null:
		var me := Game.instance.local_player
		for p: Player in Game.instance.players():
			if p == me or not is_out(p.global_position):
				continue
			seen[p.peer_id] = true
			var f: Dictionary = _figures.get(p.peer_id, {})
			if f.is_empty() or f.look != p.look() or not is_instance_valid(f.node):
				if not f.is_empty() and is_instance_valid(f.node):
					f.node.queue_free()
				f = {"node": _figure(p.look(), p.peer_id), "look": p.look(), "stride": 0.0}
				own.add_child(f.node)
				_figures[p.peer_id] = f
			var n: Node3D = f.node
			var at := p.global_position - ORIGIN
			var moved := Vector2(at.x - n.position.x, at.z - n.position.z).length()
			n.position = at
			n.rotation.y = p.rotation.y
			f.stride += moved * 6.0
			var swing := sin(f.stride) * clampf(moved / maxf(delta, 0.001) / 3.0, 0.0, 1.0) * 0.6
			var limbs: Dictionary = n.get_meta("limbs")
			limbs.leg_l.rotation.x = swing
			limbs.leg_r.rotation.x = -swing
			limbs.arm_l.rotation.x = -swing * 0.8
			limbs.arm_r.rotation.x = swing * 0.8
	for id: int in _figures.keys():
		if not seen.has(id):
			if is_instance_valid(_figures[id].node):
				_figures[id].node.queue_free()
			_figures.erase(id)


func _figure(look: Dictionary, peer: int) -> Node3D:
	var n := Node3D.new()
	var hue: float = look.get("hue", -1.0)
	var shirt := Color.from_hsv(fposmod(peer * 0.618034, 1.0) if hue < 0.0 else hue, 0.45, 0.85)
	var body := Node3D.new()
	n.add_child(body)
	n.set_meta("limbs", Crewman.build_body(body, look, shirt))
	var face := Node3D.new()
	face.position.y = Player.EYE_HEIGHT
	n.add_child(face)
	Crewman.build_face(face, look)
	Player._make_hat(face, look.get("hat", "dixie"))
	return n


## The deck hatch: E goes back below, to the foot of the ladder by the gun.
class Hatch extends Node3D:
	func get_prompt(_player: Player) -> String:
		return "[E] Go below"

	func interact(player: Player) -> void:
		player.go_below()
