class_name Deck
extends Node3D
## Out on deck (Blaney: "when the sub is high enough above water make it possible to get out and
## walk on the top of it"). The interior never moves, so the casing is built a second time as
## plain collision far above the boat, in our own boat's coordinates (OwnBoat.dims: z bow
## to stern, y up from the waterline). A crewman up here walks on that; what everyone sees is
## the exterior ocean through a camera on the real model, and the crew on deck stand there as
## crewman figures. Over the side is the sea: you swim, and climb back up the rungs amidships.
## Going out is surfaced only. While anyone without a dive suit is out the boat can't dive
## (Blaney); if she goes under anyway (flooding), they are sent down the hatch. Divers in suits
## (Diving) stay out: they hold on at the grab rails, or let go and swim while she moves on
## past them, and come below only once she's surfaced.

const ORIGIN := Vector3(0, 400, 0) ## where the deck's waterline sits in the interior's space
const SWIM_EYE := 0.35 ## m the eye rides above the water while swimming
const IN_WATER := -0.6 ## local feet height below which a crewman is swimming
const SEGMENTS := 48

var dims := {}
var _view: CanvasLayer
var _figures := {} ## peer id -> {node, look, last}
var _sea: AudioStreamPlayer
var _was_on := false
var _bout_view: CanvasLayer ## the wrestling panel, while a bout is on and we're out on deck
var _bout_lines: Array[Label] = []
var _thrown := -1.0 ## the bout (its start time) we were already thrown out of
var fishing: Fishing ## the local player's rod, while he fishes off the stern
var holds: Array[Vector3] = [] ## the grab rails' spots (deck space), where a diver holds on
var holding := -1 ## the grab rail the local diver holds, or -1
var drift := Vector3.ZERO ## how the sea moves past the local diver (deck space, m/s), for his feet
var strain := 0.0 ## 0..1 how near the local diver is to blacking out from the depth
var blacked_out := false
var _pen: Array[StaticBody3D] = [] ## the walls and floor round her that keep swimmers close, surfaced only
var _last_depth := 0.0
var _helmet: CanvasLayer ## the diver's view out of his helmet or mask
var _lamp: SpotLight3D ## the diver's lamp, deep down
var _rails_built := false


static func create(sub: SubClassData) -> Deck:
	var d := Deck.new()
	d.name = "Deck"
	d.dims = ShipModels.own_dims(sub)
	return d


## Is this point (interior space) out on deck or in the sea around it?
static func is_out(p: Vector3) -> bool:
	return p.y > ORIGIN.y - 40.0


static func is_swimming(p: Vector3) -> bool:
	return is_out(p) and p.y - ORIGIN.y < Diving.water_y() + IN_WATER


## Under the water altogether, the eye too: a diver while she's dived.
static func is_under(p: Vector3) -> bool:
	return is_out(p) and p.y - ORIGIN.y + Player.EYE_HEIGHT < Diving.water_y() - 0.2


## The sea floor under this point (interior space), as a height in the interior's space.
static func floor_at(p: Vector3) -> float:
	var sub := Sim.world.sub
	var w := Diving.world_of(sub, p - ORIGIN)
	return ORIGIN.y + Diving.water_y() - Sim.world.seabed.floor_depth(w)


func _ready() -> void:
	position = ORIGIN
	var l: float = dims.length
	var beam: float = dims.beam
	# The hull, a convex slice per station from her real sections (OwnBoat): walk the flat casing,
	# slide off its curve into the sea.
	for i in SEGMENTS:
		var pts := PackedVector3Array()
		for t in [float(i) / SEGMENTS, float(i + 1) / SEGMENTS]:
			for k in 24:
				pts.append(OwnBoat.section(dims, t, TAU * k / 24.0))
		_convex(pts)
	# The fin, a slice per few metres of its length.
	var z0: float = float(dims.ct_z) - float(dims.ct_len) * 0.5
	var y0 := OwnBoat.deck_y(dims, OwnBoat.t_of(dims, z0)) - 0.4
	for j in 10:
		var pts := PackedVector3Array()
		for s in [j / 10.0, (j + 1) / 10.0]:
			var w := maxf(OwnBoat.fin_half(dims, s), 0.05)
			var z: float = z0 + s * float(dims.ct_len)
			for side in [-1.0, 1.0]:
				pts.append(Vector3(side * w, y0, z))
				pts.append(Vector3(side * w, y0 + 0.4 + OwnBoat.fin_h(dims, s), z))
		_convex(pts)
	if dims.guns: # the gun's pedestal and the ready-use lockers
		_solid(Vector3(1.4, 1.6, 1.6), Vector3(0, _deck_at(dims.gun_z) + 0.8, dims.gun_z))
		for side in [-1.0, 1.0]:
			var lz := z0 - 1.5
			_solid(Vector3(0.6, 0.7, 1.4), Vector3(side * beam * 0.2, _deck_at(lz) + 0.35, lz))
	# Nobody swims off over the horizon: a pen of sea round her, and a floor under it.
	var pen := Vector2(beam * 0.5 + 40.0, l * 0.5 + 40.0)
	for side in [-1.0, 1.0]:
		_pen.append(_solid(Vector3(1.0, 30.0, pen.y * 2.0), Vector3(side * pen.x, 5.0, 0)))
		_pen.append(_solid(Vector3(pen.x * 2.0, 30.0, 1.0), Vector3(0, 5.0, side * pen.y)))
	_pen.append(_solid(Vector3(pen.x * 2.0, 1.0, pen.y * 2.0), Vector3(0, -14.0, 0)))
	# The grab rails a diver holds on to (Blaney): either side of the bow, the fin and the after casing.
	var bz := -l * 0.5 + l * 0.12
	var bt := OwnBoat.t_of(dims, bz)
	var fin_w := OwnBoat.fin_half(dims, 0.5) + 0.6
	var az: float = float(dims.ladder_z) - 1.5
	var at := OwnBoat.t_of(dims, az)
	for side in [-1.0, 1.0]:
		holds.append(Vector3(side * minf(0.9, OwnBoat.deck_half(dims, bt) * 0.5), OwnBoat.deck_y(dims, bt) + 0.05, bz))
		holds.append(Vector3(side * fin_w, _deck_at(float(dims.ct_z)) + 0.05, float(dims.ct_z)))
		holds.append(Vector3(side * (OwnBoat.deck_half(dims, at) - 0.6), OwnBoat.deck_y(dims, at) + 0.05, az))
	for i in holds.size():
		var g := HoldSpot.new()
		g.index = i
		g.position = holds[i]
		add_child(g)
		Build.area(g, Vector3(1.2, 1.6, 1.2), Vector3(0, 0.8, 0))
	# The diving locker beside the hatch, where the suits are stowed.
	var locker := SuitLocker.new()
	locker.position = Vector3(1.6, _deck_at(dims.hatch_z), dims.hatch_z)
	add_child(locker)
	Build.area(locker, Vector3(1.0, 1.4, 1.0), Vector3(0, 0.6, 0))
	# The hatch back down, and a ladder from the water up each side.
	var hatch := Hatch.new()
	hatch.position = Vector3(0, _deck_at(dims.hatch_z), dims.hatch_z)
	add_child(hatch)
	Build.area(hatch, Vector3(1.4, 0.8, 1.4), Vector3(0, 0.3, 0))
	# The stern rail, starboard, where a man can fish (Blaney).
	var fz := minf(float(dims.ring_z) + 4.0, l * 0.5 - 3.0)
	var ft := OwnBoat.t_of(dims, fz)
	var rod := FishingSpot.new()
	rod.position = Vector3(OwnBoat.deck_half(dims, ft) - 0.4, OwnBoat.deck_y(dims, ft), fz)
	add_child(rod)
	Build.area(rod, Vector3(1.4, 1.6, 1.6), Vector3(0, 0.8, 0))
	var lz: float = dims.ladder_z
	var lt := OwnBoat.t_of(dims, lz)
	var dk := OwnBoat.deck_y(dims, lt)
	var edge := OwnBoat.deck_half(dims, lt)
	for side in [-1.0, 1.0]:
		var hw := maxf(OwnBoat.half_at(dims, lt, 0.0), edge)
		var ladder := Ladder.new()
		ladder.label_up = "Climb aboard"
		ladder.label_down = "Climb down into the sea"
		add_child(ladder)
		ladder.top_y = ORIGIN.y + dk
		ladder.bottom_path = [ORIGIN + Vector3(side * (hw + 0.55), SWIM_EYE - Player.EYE_HEIGHT, lz),
			ORIGIN + Vector3(side * (hw + 0.55), dk + 0.15, lz), ORIGIN + Vector3(side * (edge - 0.7), dk + 0.05, lz)]
		Build.area(ladder, Vector3(maxf(hw - edge, 0.0) + 1.6, dk + 2.0, 1.2), Vector3(side * ((hw + edge) * 0.5 + 0.3), dk * 0.5 - 0.6, lz))


func _deck_at(z: float) -> float:
	return OwnBoat.deck_y(dims, OwnBoat.t_of(dims, z))


func _convex(pts: PackedVector3Array) -> void:
	var body := StaticBody3D.new()
	body.name = "DeckSolid"
	var shape := CollisionShape3D.new()
	var cs := ConvexPolygonShape3D.new()
	cs.points = pts
	shape.shape = cs
	body.add_child(shape)
	add_child(body)


func _solid(size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := Build.hitbox(self, size, pos)
	body.name = "DeckSolid"
	return body


## Where a crewman coming up the hatch stands (interior space), facing forward.
func hatch_spot() -> Vector3:
	return ORIGIN + Vector3(0, _deck_at(dims.hatch_z) + 0.05, float(dims.hatch_z) - 0.9)


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
	_sync_figures(delta)
	_sync_bout(on)
	_build_rails()
	_dive(me, on, delta)
	if is_instance_valid(fishing) and (not on or me.is_knocked_out()):
		fishing.queue_free()


## Standing in the wrestling ring on the aft casing (not swimming)?
func in_ring(p: Vector3) -> bool:
	var at := p - ORIGIN
	return is_out(p) and absf(at.z - float(dims.ring_z)) < 1.0 and absf(at.x) < float(dims.ring_edge) - 0.3 \
		and at.y > float(dims.deck) - 0.5


## The bout this crewman is fighting in, or empty.
func bout_of(peer: int) -> Dictionary:
	var w: Dictionary = Game.instance.crew.get("wrestle", {})
	if w.is_empty() or w.phase == "done" or (w.a != peer and w.b != peer):
		return {}
	return w


## Where a wrestler stands in the clinch (interior space) and which way he faces.
func bout_spot(w: Dictionary, peer: int) -> Transform3D:
	var side := -1.0 if peer == w.a else 1.0
	var at := ORIGIN + Vector3(float(w.pos) + side * Wrestling.GAP, float(dims.deck) + 0.02, float(dims.ring_z))
	var t := Transform3D(Basis(Vector3.UP, side * PI / 2.0), at) # facing the other man, across the deck
	return t


## The local wrestler is held in the clinch: Deck places him, his feet don't move him.
func pinned(player: Player) -> bool:
	return not bout_of(player.peer_id).is_empty() or (player.is_local() and (is_instance_valid(fishing) or holding >= 0))


## The local diver's lot each frame: the sea moving past him, holding on, the depth on him,
## the lifeline back, his helmet's view and lamp.
func _dive(me: Player, on: bool, delta: float) -> void:
	var sub := Sim.world.sub
	var sink := (sub.depth - _last_depth) / maxf(delta, 0.001)
	_last_depth = sub.depth
	var dived := Diving.water_y() > 0.0
	for b in _pen:
		b.collision_layer = 0 if dived else 1
	if me == null or not on:
		holding = -1
		drift = Vector3.ZERO
		strain = 0.0
		blacked_out = false
		_show_helmet(false)
		return
	var local := me.global_position - ORIGIN
	_show_helmet(Diving.suited(me.peer_id))
	if dived and holding < 0:
		drift = Diving.drift_at(sub, local, clampf(sink, -5.0, 5.0))
		me.rotation.y += deg_to_rad(sub.turn_rate) * delta # he keeps facing the same way in the sea
	else:
		drift = Vector3.ZERO
	if not dived and local.y < -13.0: # she came up under him: he bobs up beside her
		me.global_position = ORIGIN + Vector3(local.x, 0.0, local.z)
	# The depth on him: past the suit's depth he strains, then blacks out on his lifeline.
	var deep := Diving.water_y() - (local.y + Player.EYE_HEIGHT)
	var limit: float = Diving.suit().depth
	var was := strain
	strain = clampf(strain + delta * (1.0 / Diving.STRAIN_TIME if deep > limit else -0.25), 0.0, 1.0)
	if was < 0.15 and strain >= 0.15:
		Game.instance.hud.show_message("Too deep for the %s! Tell them to come up." % Diving.suit().name, 5.0)
	if strain >= 1.0 and not blacked_out:
		blacked_out = true
		grab(nearest_hold(local))
	elif blacked_out and strain < 0.3 and deep < limit:
		blacked_out = false
		Game.instance.hud.show_message("You come round, hanging on your lifeline.", 4.0)
	if holding >= 0:
		me.global_position = ORIGIN + holds[holding]
		me.velocity = Vector3.ZERO
		if not blacked_out and Input.is_action_just_pressed("jump") and not Game.instance.menu_open():
			holding = -1
	elif far_from_boat(local) and Input.is_action_just_pressed("lifeline") and not Game.instance.menu_open():
		haul_back(me)
	if _lamp != null:
		_lamp.visible = Diving.suited(me.peer_id) and deep > 12.0


## Holds on at grab rail `i` (or lets go with -1).
func grab(i: int) -> void:
	holding = i
	var me := Game.instance.local_player
	if i >= 0 and me != null:
		me.global_position = ORIGIN + holds[i]
		me.velocity = Vector3.ZERO


func nearest_hold(local: Vector3) -> int:
	var best := 0
	for i in holds.size():
		if holds[i].distance_to(local) < holds[best].distance_to(local):
			best = i
	return best


## Further from her hull than a man can swim back in a hurry?
func far_from_boat(local: Vector3) -> bool:
	var l: float = dims.length
	var dz := maxf(absf(local.z) - l * 0.5, 0.0)
	var dx := maxf(absf(local.x) - float(dims.beam) * 0.5, 0.0)
	var dy := maxf(absf(local.y - float(dims.deck) * 0.5) - float(dims.deck) - float(dims.draft), 0.0)
	return Vector3(dx, dy, dz).length() > Diving.FAR


## The lifeline: back to her, holding on at the nearest rail while she's dived, at the foot of
## a side ladder on the surface.
func haul_back(me: Player) -> void:
	var local := me.global_position - ORIGIN
	if Diving.water_y() > 0.0:
		grab(nearest_hold(local))
	else:
		var side := signf(local.x) if local.x != 0.0 else 1.0
		me.global_position = ORIGIN + Vector3(side * (float(dims.beam) * 0.5 + 1.5), 0.0, float(dims.ladder_z))
		me.velocity = Vector3.ZERO
	Sfx.play_at(me, "splash", Vector3(0, 1.0, 0), -6.0)


## What the local player sees of the diving gear: the view out of the helmet's front window
## (the hard hat), or the mask's edge; and his lamp in the sea.
func _show_helmet(on: bool) -> void:
	if on == (_helmet != null):
		return
	if not on:
		_helmet.queue_free()
		_helmet = null
		if _lamp != null:
			_lamp.queue_free()
			_lamp = null
		return
	_helmet = CanvasLayer.new()
	_helmet.layer = 0
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = HELMET_SHADER
	var era: String = Game.instance.sub_class.era
	m.set_shader_parameter("round_window", era == "ww2")
	m.set_shader_parameter("frame", Color("#B08A3A") if era == "ww2" else Color("#1A1C1E"))
	r.material = m
	_helmet.add_child(r)
	add_child(_helmet)
	_lamp = SpotLight3D.new()
	_lamp.light_color = Color("#FFF1D0")
	_lamp.light_energy = 6.0
	_lamp.spot_range = 45.0
	_lamp.spot_angle = 28.0
	_lamp.visible = false
	Game.instance.exterior.camera.add_child(_lamp)


const HELMET_SHADER := """
shader_type canvas_item;
uniform bool round_window = true;
uniform vec4 frame : source_color = vec4(0.69, 0.54, 0.23, 1.0);
void fragment() {
	vec2 px = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = (SCREEN_UV - 0.5) * vec2(px.x / px.y, 1.0);
	float d = round_window ? length(p) / 0.47 : length(p * vec2(0.62, 0.95)) / 0.47;
	float rim = smoothstep(0.96, 1.0, d) * (1.0 - smoothstep(1.08, 1.12, d));
	float dark = smoothstep(1.06, 1.1, d);
	vec3 c = mix(frame.rgb * (0.7 + 0.5 * (0.5 - p.y)), vec3(0.03), dark);
	COLOR = vec4(c, max(rim, dark));
}
"""


## Grab rails on our boat's outside, where a diver holds on (seen from the deck and the cameras).
func _build_rails() -> void:
	var own: Node3D = Game.instance.exterior.own_boat()
	if _rails_built or own == null:
		return
	_rails_built = true
	var steel := Color("#3A3D40")
	var kit := Node3D.new()
	kit.name = "GrabRails"
	own.add_child(kit)
	for h in holds:
		var along := absf(h.x) > float(dims.beam) * 0.2 and absf(h.z - float(dims.ct_z)) < 1.0 # on the fin's side
		var x := h.x - signf(h.x) * (0.55 if along else 0.0)
		Build.box(kit, Vector3(0.06, 0.06, 0.9), Vector3(x, h.y + (1.1 if along else 0.3), h.z), steel, false)
		for e in [-0.42, 0.42]:
			Build.box(kit, Vector3(0.05, 0.3, 0.05), Vector3(x, h.y + (0.95 if along else 0.15), h.z + e), steel, false)
	var lz: float = dims.hatch_z
	var box := Build.box(kit, Vector3(0.8, 0.9, 0.6), Vector3(1.6, _deck_at(lz) + 0.45, lz), Color("#5A6066"), false)
	var tag := Label3D.new()
	tag.text = "DIVING GEAR"
	tag.font_size = 40
	tag.pixel_size = 0.004
	tag.position = Vector3(0, 0.15, -0.31)
	tag.rotation.y = PI
	box.add_child(tag)
	ExteriorWorld.set_own_layer(kit)


func _sync_bout(on: bool) -> void:
	var me := Game.instance.local_player
	var w: Dictionary = Game.instance.crew.get("wrestle", {})
	var show := on and not w.is_empty()
	if me != null and not w.is_empty():
		var mine: bool = not bout_of(me.peer_id).is_empty()
		if mine:
			var t := bout_spot(w, me.peer_id)
			me.global_position = t.origin
			me.rotation.y = t.basis.get_euler().y
			me.velocity = Vector3.ZERO
		# Lost: over the side on our own edge, into the sea.
		if w.phase == "done" and int(w.winner) != me.peer_id and (w.a == me.peer_id or w.b == me.peer_id) and _thrown != float(w.start):
			_thrown = float(w.start)
			var side := -1.0 if me.peer_id == w.a else 1.0
			me.global_position = ORIGIN + Vector3(side * (float(dims.ring_edge) + 1.6), -0.9, float(dims.ring_z))
			me.velocity = Vector3.ZERO
	if not show:
		if _bout_view != null:
			_bout_view.queue_free()
			_bout_view = null
		return
	if _bout_view == null:
		_bout_view = CanvasLayer.new()
		_bout_view.layer = 2
		add_child(_bout_view)
		var root := UiKit.overlay_root()
		root.theme = UiKit.theme()
		_bout_view.add_child(root)
		var box := UiKit.bottom_panel(root)
		_bout_lines.clear()
		for i in 5:
			var l := UiKit.label("", 22 if i == 0 else 18, UiKit.BRASS if i == 0 else UiKit.CREAM)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(l)
			_bout_lines.append(l)
	var g := Game.instance
	var mine: bool = me != null and (w.a == me.peer_id or w.b == me.peer_id)
	var left := maxf(0.0, float(w.until) - Sim.world.time)
	var na := g.crew_name(int(w.a))
	var nb := g.crew_name(int(w.b))
	_bout_lines[0].text = "WRESTLING — %s (port) vs %s (starboard)" % [na, nb]
	# The clinch between the two edges: port | ...X... | starboard
	var edge: float = dims.ring_edge
	var cells := 21
	var at := clampi(roundi((float(w.pos) + edge) / (edge * 2.0) * (cells - 1)), 0, cells - 1)
	var bar := ""
	for i in cells:
		bar += "X" if i == at else "-"
	var state := ""
	if int(w.lock) != 0:
		state += "   %s has a body lock" % g.crew_name(int(w.lock))
	if int(w.off) != 0:
		state += "   %s is off balance" % g.crew_name(int(w.off))
	_bout_lines[1].text = "SEA |%s| SEA%s" % [bar, state]
	match String(w.phase):
		"count":
			_bout_lines[2].text = "Into the clinch ... %d" % ceili(left)
		"choose":
			var picked: bool = mine and w.moves.has("a" if w.a == me.peer_id else "b")
			if mine:
				_bout_lines[2].text = ("Move picked: %s. Waiting ... %d" % [Wrestling.NAMES[w.moves["a" if w.a == me.peer_id else "b"]], ceili(left)]) if picked \
						else "Pick your move (%d s):\n[1] Push   [2] Arm drag   [3] Body lock\n[4] Suplex (needs a lock)   [5] Brace" % ceili(left)
			else:
				_bout_lines[2].text = "They're picking their moves ... %d" % ceili(left)
		"show":
			_bout_lines[2].text = ""
		"done":
			_bout_lines[2].text = "%s wins!" % g.crew_name(int(w.winner))
	var last := String(w.last).split("\n")
	_bout_lines[3].text = last[0] if last.size() > 0 else ""
	_bout_lines[4].text = "\n".join(last.slice(1)) if last.size() > 1 else "Greco-Roman: upper body only. Drive him off his edge into the sea."


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
func _sync_figures(delta: float) -> void:
	var own: Node3D = Game.instance.exterior.own_boat() # the figures show from the outside cameras too
	var seen := {}
	if own != null:
		var me := Game.instance.local_player
		for p: Player in Game.instance.players():
			if p == me or not is_out(p.global_position):
				continue
			seen[p.peer_id] = true
			var f: Dictionary = _figures.get(p.peer_id, {})
			var suit := Diving.suited(p.peer_id)
			if f.is_empty() or f.look != p.look() or f.suit != suit or not is_instance_valid(f.node):
				if not f.is_empty() and is_instance_valid(f.node):
					f.node.queue_free()
				f = {"node": _figure(p.look(), p.peer_id, suit), "look": p.look(), "suit": suit, "stride": 0.0}
				own.add_child(f.node)
				ExteriorWorld.set_own_layer(f.node)
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
			if not bout_of(p.peer_id).is_empty(): # in the clinch: arms round the other man, leaning in
				limbs.arm_l.rotation.x = 1.25
				limbs.arm_r.rotation.x = 1.25
				n.rotation.y = bout_spot(bout_of(p.peer_id), p.peer_id).basis.get_euler().y
				n.get_child(0).rotation.x = -0.2
			else:
				n.get_child(0).rotation.x = 0.0
	for id: int in _figures.keys():
		if not seen.has(id):
			if is_instance_valid(_figures[id].node):
				_figures[id].node.queue_free()
			_figures.erase(id)


func _figure(look: Dictionary, peer: int, suit := false) -> Node3D:
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
	if suit:
		Crewman.dress_diver(body, face, Game.instance.sub_class.era)
	else:
		Player._make_hat(face, look.get("hat", "dixie"))
	return n


## The deck hatch: E goes back below, to the foot of the ladder by the gun.
class Hatch extends Node3D:
	func get_prompt(_player: Player) -> String:
		return "Hatch shut: she's dived. Wait for her to surface" if Diving.water_y() > 0.0 else "[E] Go below"

	func interact(player: Player) -> void:
		if Diving.water_y() <= 0.0:
			player.go_below()


## A grab rail: E holds on (a diver rides along while she's dived), E or Space lets go.
class HoldSpot extends Node3D:
	var index := 0

	func get_prompt(_player: Player) -> String:
		var d := Game.instance.deck
		return "Holding on  —  [Space] let go" if d.holding == index else "[E] Hold on"

	func interact(_player: Player) -> void:
		var d := Game.instance.deck
		if not d.blacked_out:
			d.grab(-1 if d.holding == index else index)


## The diving locker beside the hatch: E puts the boat's dive suit on, or takes it off (surfaced).
class SuitLocker extends Node3D:
	func get_prompt(player: Player) -> String:
		var on := Diving.suited(player.peer_id)
		if Diving.water_y() > 0.0:
			return "Diving locker" if on else ""
		return "[E] Take the dive suit off" if on else "[E] Put on the %s" % Diving.suit().name

	func interact(player: Player) -> void:
		if Diving.water_y() <= 0.0:
			Game.instance.rq_suit.rpc_id(1, not Diving.suited(player.peer_id))


## The stern rail: E takes up a rod and fishes (Fishing), E again puts it down.
class FishingSpot extends Node3D:
	func get_prompt(_player: Player) -> String:
		var d := Game.instance.deck
		return "[E] Put the rod down" if is_instance_valid(d.fishing) else "[E] Fish off the stern"

	func interact(_player: Player) -> void:
		var d := Game.instance.deck
		if is_instance_valid(d.fishing):
			d.fishing.queue_free()
		else:
			d.fishing = Fishing.new()
			d.add_child(d.fishing)
