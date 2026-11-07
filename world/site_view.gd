class_name SiteView
extends Node3D
## A place on the sea floor (Seabed kind "site"), drawn low-poly in flat colours like everything
## else, standing on its rise: the wreck of a freighter broken in two, a drowned temple of steps
## and columns with a sealed door, black smokers with glowing mouths, a garden of glowing kelp and
## anemones, and a crystal city of spires and domes pulsing purple and teal (Blaney). Each one's
## event (Game.site_event, once crew.found has it) shows here too: the temple's door sinks open on
## a glow, a swarm of glowing fish rings the boat in the garden, and a glowing orb rises out of the
## crystal city and follows the boat a minute before it leaves.

const ORB_TIME := 60.0 ## s the city's orb follows us
const SWARM_TIME := 60.0
const SWARM := 160

var f: Dictionary
var _pulse: Array[StandardMaterial3D] = [] ## glows that throb (the city, the vents, the garden)
var _sway: Array[Node3D] = [] ## kelp
var _door: Node3D
var _door_glow: OmniLight3D
var _orb: Node3D
var _swarm: MultiMeshInstance3D
var _time := 0.0
var _rng := RandomNumberGenerator.new()


static func build(feature: Dictionary, rng: RandomNumberGenerator) -> SiteView:
	var v := SiteView.new()
	v.f = feature
	v.name = "Site_%s" % feature.type
	v.position = Vector3(float(feature.x), -float(feature.top), -float(feature.y))
	v._rng.seed = rng.randi()
	match str(feature.type):
		"wreck":
			v._wreck()
		"ruins":
			v._ruins()
		"vents":
			v._vents()
		"garden":
			v._garden()
		"alien":
			v._alien()
	return v


func _glow(c: Color, energy: float, pulse := false, see_through := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	if see_through:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if pulse:
		m.set_meta("energy", energy)
		m.set_meta("phase", _rng.randf() * TAU)
		_pulse.append(m)
	return m


func _mesh(mesh: Mesh, pos: Vector3, material: Material, rot := Vector3.ZERO, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _light(pos: Vector3, c: Color, energy: float, reach: float, parent: Node3D = self) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = reach
	l.position = pos
	parent.add_child(l)
	return l


static func _prism(r_bottom: float, r_top: float, h: float, sides := 6) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.bottom_radius = r_bottom
	m.top_radius = r_top
	m.height = h
	m.radial_segments = sides
	m.rings = 1
	return m


# --- The wreck: a freighter broken in two, lying over on her side, cargo spilled ------------

func _wreck() -> void:
	var rust := Color("#6B3E26")
	var dark := Color("#3A3A36")
	var bow := Node3D.new()
	bow.rotation = Vector3(0.0, 0.3, 0.5) # listing hard over
	add_child(bow)
	Build.box(bow, Vector3(9.0, 7.0, 46.0), Vector3(0, 3.0, -26.0), rust, false)
	Build.box(bow, Vector3(6.0, 5.0, 10.0), Vector3(0, 3.5, -52.0), rust, false) # the bow's taper
	Build.box(bow, Vector3(8.0, 0.4, 44.0), Vector3(0, 6.6, -26.0), dark, false) # her deck
	for k in 2: # hatch coamings, one lid gone
		Build.box(bow, Vector3(5.0, 1.0, 6.0), Vector3(0, 7.3, -18.0 - k * 14.0), dark, false)
	Build.cyl(bow, 0.35, 16.0, Vector3(0, 14.0, -30.0), dark) # her foremast, still standing
	var stern := Node3D.new()
	stern.position = Vector3(6.0, 0, 10.0)
	stern.rotation = Vector3(0.1, -0.25, 0.25)
	add_child(stern)
	Build.box(stern, Vector3(9.0, 7.0, 38.0), Vector3(0, 3.0, 18.0), rust, false)
	Build.box(stern, Vector3(7.0, 6.0, 9.0), Vector3(0, 9.0, 12.0), Color("#C9C1A8"), false) # the bridge house
	Build.box(stern, Vector3(7.4, 0.5, 9.4), Vector3(0, 12.2, 12.0), dark, false)
	var funnel := Build.cyl(stern, 1.8, 7.0, Vector3(4.0, 8.0, 22.0), Color("#2A2A2A"))
	funnel.rotation.z = 1.2 # knocked flat
	Build.cyl(stern, 0.4, 2.2, Vector3(0, 2.0, 37.5), Color("#8A6A3A"), Vector3.BACK) # the screw's shaft
	for k in 4:
		var blade := Build.box(stern, Vector3(0.4, 2.4, 0.3), Vector3(0, 2.0, 38.6), Color("#8A6A3A"), false)
		blade.rotation.z = k * PI / 2.0 + 0.3
	for i in 14: # spilled crates and drums
		var at := Vector3(_rng.randf_range(-20.0, 20.0), 0.6, _rng.randf_range(-15.0, 10.0))
		if _rng.randf() < 0.5:
			Build.box(self, Vector3(1.6, 1.2, 2.2), at, Color("#5A4630"), false).rotation.y = _rng.randf() * TAU
		else:
			var drum := Build.cyl(self, 0.45, 1.2, at, Color("#4A5A3A"), Vector3.RIGHT)
			drum.rotation.y = _rng.randf() * TAU
	var tag := Build.label(stern, "KIYO MARU", Vector3(4.6, 3.4, 30.0), 300, Color("#C9C1A8"))
	tag.rotation.y = PI / 2.0
	_light(Vector3(0, 18.0, 0), Color("#7FA8B0"), 0.6, 70.0) # a little of the day reaching down


# --- The drowned temple: three steps, a ring of columns, a gate with a sealed door ----------

func _ruins() -> void:
	var stone := Color("#8C8A7A")
	var moss := Color("#5E7A55")
	for k in 3:
		Build.box(self, Vector3(44.0 - k * 12.0, 3.0, 44.0 - k * 12.0), Vector3(0, 1.5 + k * 3.0, 0), stone if k != 1 else moss, false)
	for i in 12:
		var a := TAU * i / 12.0
		var at := Vector3(cos(a) * 18.0, 3.0, sin(a) * 18.0)
		var broken := _rng.randf() < 0.35
		var h := _rng.randf_range(3.0, 6.0) if broken else 12.0
		var col := Build.cyl(self, 1.1, h, at + Vector3(0, h * 0.5, 0), stone)
		if broken and _rng.randf() < 0.5: # one lying where it fell
			var fallen := Build.cyl(self, 1.1, 9.0, at + Vector3(cos(a) * 5.0, 1.0, sin(a) * 5.0), stone)
			fallen.rotation = Vector3(PI / 2.0, a, 0)
		elif not broken:
			Build.box(self, Vector3(3.0, 1.0, 3.0), at + Vector3(0, h + 0.5, 0), stone, false)
		col.rotation.z = _rng.randf_range(-0.06, 0.06)
	# The gate on the top step, facing south, with its door shut on whatever glows inside.
	var top := 9.0
	for side in [-1.0, 1.0]:
		Build.box(self, Vector3(2.5, 10.0, 2.5), Vector3(side * 4.0, top + 5.0, 6.0), stone, false)
	Build.box(self, Vector3(11.0, 2.5, 3.0), Vector3(0, top + 11.0, 6.0), stone, false)
	Build.box(self, Vector3(14.0, 9.0, 10.0), Vector3(0, top + 4.5, 0.0), moss, false) # the shrine behind
	var inside := _mesh(BoxMesh.new(), Vector3(0, top + 3.8, 5.1), _glow(Color("#7FE0D0"), 2.5, true))
	(inside.mesh as BoxMesh).size = Vector3(5.0, 7.4, 0.2)
	_door = Node3D.new()
	_door.position = Vector3(0, top + 3.8, 6.2)
	add_child(_door)
	Build.box(_door, Vector3(5.4, 7.6, 0.8), Vector3.ZERO, Color("#6E6A5C"), false)
	for k in 3: # carved bands
		Build.box(_door, Vector3(4.6, 0.3, 0.2), Vector3(0, -2.4 + k * 2.4, 0.45), Color("#A8A28A"), false)
	_door_glow = _light(Vector3(0, top + 4.0, 9.0), Color("#7FE0D0"), 0.0, 40.0)


# --- Black smokers: chimneys, glowing mouths, tube worms ------------------------------------

func _vents() -> void:
	var black := Color("#1E1E22")
	for i in 7:
		var at := Vector3(_rng.randf_range(-22.0, 22.0), 0, _rng.randf_range(-22.0, 22.0))
		var h := _rng.randf_range(10.0, 26.0)
		var r := _rng.randf_range(1.4, 2.8)
		var y := 0.0
		for k in 3: # stacked, knobbly, narrowing
			var seg := h / 3.0
			_mesh(_prism(r * (1.0 - k * 0.25), r * (0.85 - k * 0.25), seg, 7), at + Vector3(_rng.randf_range(-0.4, 0.4), y + seg * 0.5, 0), Build.mat(black))
			y += seg
		var mouth := _mesh(_prism(r * 0.45, r * 0.3, 0.6, 7), at + Vector3(0, h + 0.2, 0), _glow(Color("#FF7A2A"), 4.0, true))
		var smoke := Build.particles(self, Color(0.15, 0.13, 0.12, 0.8), 40, 6.0, Vector3.UP, 4.0, 12.0, Vector3(0, 0.6, 0), 2.2)
		smoke.position = mouth.position + Vector3(0, 0.6, 0)
		_light(at + Vector3(0, h + 2.0, 0), Color("#FF8A3A"), 1.2, 30.0)
		for w in 10: # tube worms round its foot, red-tipped
			var p := at + Vector3(_rng.randf_range(-4.0, 4.0), 0.0, _rng.randf_range(-4.0, 4.0))
			var len := _rng.randf_range(1.0, 2.2)
			Build.cyl(self, 0.12, len, p + Vector3(0, len * 0.5, 0), Color("#E8E2D0"))
			Build.sphere(self, 0.2, p + Vector3(0, len, 0), Color("#D0302A"), 0.8)
	var glow_floor := _mesh(_prism(30.0, 30.0, 0.1, 24), Vector3(0, 0.15, 0), _glow(Color("#5A1A08"), 0.6, true, true)) # the warm ground round them
	glow_floor.material_override.albedo_color.a = 0.5


# --- The glowing garden: kelp, anemones, fan coral --------------------------------------------

func _garden() -> void:
	var glows := [Color("#4FF0D0"), Color("#FF6FB0"), Color("#9BE564"), Color("#5FC8FF"), Color("#FFD24F")]
	for i in 40:
		var at := Vector3(_rng.randf_range(-30.0, 30.0), 0, _rng.randf_range(-30.0, 30.0))
		var stalk := Node3D.new()
		stalk.position = at
		stalk.set_meta("phase", _rng.randf() * TAU)
		add_child(stalk)
		var h := _rng.randf_range(6.0, 14.0)
		Build.box(stalk, Vector3(0.25, h, 0.25), Vector3(0, h * 0.5, 0), Color("#3E6B34"), false)
		for k in int(h / 2.0):
			var leaf := Build.box(stalk, Vector3(0.9, 0.08, 0.4), Vector3(0.4, 1.5 + k * 2.0, 0), Color("#5E8F3E"), false)
			leaf.rotation.y = k * 1.3
		_sway.append(stalk)
	for i in 60:
		var at := Vector3(_rng.randf_range(-28.0, 28.0), 0.4, _rng.randf_range(-28.0, 28.0))
		var c: Color = glows[_rng.randi() % glows.size()]
		var m := _mesh(SphereMesh.new(), at, _glow(c, 2.2, true))
		var r := _rng.randf_range(0.4, 1.1)
		(m.mesh as SphereMesh).radius = r
		(m.mesh as SphereMesh).height = r * 1.4
		for k in 6: # its tentacles
			Build.cyl(self, 0.06, r * 1.2, at + Vector3(cos(k) * r * 0.5, r * 0.8, sin(k) * r * 0.5), c.darkened(0.3))
	for i in 12: # fan corals
		var fan := Build.box(self, Vector3(3.0, 2.6, 0.12), Vector3(_rng.randf_range(-26.0, 26.0), 1.3, _rng.randf_range(-26.0, 26.0)), Color("#C9506A"), false)
		fan.rotation.y = _rng.randf() * TAU
	_light(Vector3(0, 6.0, 0), Color("#7FFFD0"), 1.4, 50.0)
	_light(Vector3(15, 4.0, -12), Color("#FF8FC8"), 0.8, 30.0)
	_swarm = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = SWARM
	var fish := SphereMesh.new()
	fish.radius = 0.25
	fish.height = 0.5
	fish.radial_segments = 6
	fish.rings = 3
	mm.mesh = fish
	_swarm.multimesh = mm
	_swarm.material_override = _glow(Color("#9FFFE0"), 3.0)
	_swarm.top_level = true
	_swarm.visible = false
	add_child(_swarm)


# --- The crystal city: spires, domes, symbols, pulsing purple and teal ------------------------

func _alien() -> void:
	var purple := Color("#B266FF")
	var teal := Color("#3FE8D8")
	var spires := [[0.0, 0.0, 70.0, 7.0], [16.0, 6.0, 44.0, 5.0], [-14.0, 10.0, 52.0, 5.0], [6.0, -18.0, 38.0, 4.0],
		[-20.0, -12.0, 30.0, 4.0], [24.0, -14.0, 26.0, 3.0], [-4.0, 24.0, 34.0, 4.0], [28.0, 20.0, 22.0, 3.0]]
	for s: Array in spires:
		var c := purple if _rng.randf() < 0.55 else teal
		var h := float(s[2])
		var r := float(s[3])
		_mesh(_prism(r, 0.0, h, 6), Vector3(s[0], h * 0.5, s[1]), _glow(c, 1.6, true, true), Vector3(0, _rng.randf() * TAU, 0))
		_mesh(_prism(r * 1.4, r * 1.1, 2.0, 6), Vector3(s[0], 1.0, s[1]), _glow(c.darkened(0.4), 0.8, true))
		for k in 3: # rings of light up it
			var ring := _mesh(TorusMesh.new(), Vector3(s[0], h * (0.25 + k * 0.2), s[1]), _glow(Color.WHITE.lerp(c, 0.5), 3.0, true))
			var t := ring.mesh as TorusMesh
			var rr := r * (1.0 - (0.25 + k * 0.2)) + 0.6
			t.inner_radius = rr
			t.outer_radius = rr + 0.25
	for i in 6: # domes
		var a := TAU * i / 6.0 + 0.4
		var at := Vector3(cos(a) * 34.0, 0, sin(a) * 34.0)
		var dome := _mesh(SphereMesh.new(), at, _glow(teal if i % 2 == 0 else purple, 0.9, true, true))
		var sm := dome.mesh as SphereMesh
		sm.radius = 7.0
		sm.height = 7.0
		sm.is_hemisphere = true
		(dome.material_override as StandardMaterial3D).albedo_color.a = 0.55
	var glyphs := ["◬", "⟁", "⌬", "⏃", "⍜", "⎔", "⟟", "⍙"]
	for i in 16: # symbols round the city's edge, standing in the dark
		var a := TAU * i / 16.0
		var l := Label3D.new()
		l.text = glyphs[i % glyphs.size()]
		l.font_size = 400
		l.pixel_size = 0.02
		l.modulate = purple.lightened(0.3)
		l.position = Vector3(cos(a) * 46.0, 6.0, sin(a) * 46.0)
		l.rotation.y = -a + PI / 2.0
		l.double_sided = true
		add_child(l)
	_light(Vector3(0, 30.0, 0), purple, 2.0, 120.0)
	_light(Vector3(0, 8.0, 0), teal, 1.5, 70.0)
	_orb = Node3D.new()
	_orb.top_level = true
	_orb.visible = false
	add_child(_orb)
	_mesh(SphereMesh.new(), Vector3.ZERO, _glow(Color("#E8D8FF"), 6.0, true), Vector3.ZERO, _orb)
	_light(Vector3.ZERO, Color("#C8A8FF"), 3.0, 60.0, _orb)


# --- Alive ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	for m in _pulse:
		m.emission_energy_multiplier = float(m.get_meta("energy")) * (0.65 + 0.35 * sin(_time * 1.3 + float(m.get_meta("phase"))))
	for s in _sway:
		var ph: float = s.get_meta("phase")
		s.rotation = Vector3(sin(_time * 0.7 + ph) * 0.12, 0, cos(_time * 0.5 + ph) * 0.1)
	# Looked up by name, so the picture tools can draw a site without the game's autoloads.
	var sim := get_node_or_null("/root/Sim")
	var game := get_tree().current_scene
	var world: OceanWorld = sim.get("world") if sim != null else null
	if world == null or game == null or not "crew" in game:
		return
	var found: Dictionary = game.crew.get("found", {})
	if not found.has(f.name):
		return
	var since := world.time - float(found[f.name])
	var sub := world.sub
	var boat := Vector3(sub.pos.x, -sub.depth, -sub.pos.y)
	if _door != null: # the temple's door sinks into the step, the glow spills out
		var open := clampf(since / 8.0, 0.0, 1.0)
		_door.position.y = 9.0 + 3.8 - open * 7.8
		_door_glow.light_energy = open * 2.5
	if _orb != null: # rises out of the city, keeps off our beam a while, then goes back down
		_orb.visible = since < ORB_TIME + 15.0
		if _orb.visible:
			var city := global_position + Vector3(0, 70.0, 0)
			var beside := boat + Vector3(cos(_time * 0.4) * 30.0, 6.0 + sin(_time * 0.9) * 3.0, sin(_time * 0.4) * 30.0)
			var t := clampf(since / 12.0, 0.0, 1.0) if since < ORB_TIME else 1.0 - clampf((since - ORB_TIME) / 15.0, 0.0, 1.0)
			_orb.global_position = city.lerp(beside, t)
	if _swarm != null: # a swarm of glowing fish round the boat
		_swarm.visible = since < SWARM_TIME
		if _swarm.visible:
			var mm := _swarm.multimesh
			for i in SWARM:
				var a := TAU * i / SWARM + _time * (0.5 + 0.3 * float(i % 3))
				var r := 14.0 + 10.0 * sin(i * 1.7) + 4.0 * sin(_time + i)
				var p := boat + Vector3(cos(a) * r, sin(a * 3.0 + i) * 6.0, sin(a) * r)
				mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, -a), p))
