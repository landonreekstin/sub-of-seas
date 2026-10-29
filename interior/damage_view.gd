class_name DamageView
extends Node3D
## Draws the hull damage state inside the boat: water in each compartment, leaks, fires,
## placed pumps and broken stations. Rebuilt from Sim.world.hull every frame (cheap: a
## handful of spots), so host and clients show the same thing.

var interior: GatoInterior
var _water: Array[MeshInstance3D] = []
var _smoke: Array[MeshInstance3D] = [] ## a grey haze hanging under the deckhead
var _spots := {} ## "kind:id" -> DamageSpot


func _ready() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.34, 0.36, 0.72)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	m.metallic = 0.3
	for c: Dictionary in GatoInterior.COMPARTMENTS:
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(GatoInterior.HALF_WIDTH * 2.0, 0.02, c.z1 - c.z0 - 0.2)
		mi.mesh = mesh
		mi.material_override = m
		mi.position = Vector3(0, 0, (c.z0 + c.z1) * 0.5)
		mi.visible = false
		add_child(mi)
		_water.append(mi)
		var sm := MeshInstance3D.new()
		var sbox := BoxMesh.new()
		sbox.size = Vector3(GatoInterior.HALF_WIDTH * 2.0 - 0.1, 1.0, c.z1 - c.z0 - 0.1)
		sm.mesh = sbox
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(0.35, 0.35, 0.33, 0.0)
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.material_override = smat
		sm.position = Vector3(0, GatoInterior.DECK_HEIGHT - 0.5, (c.z0 + c.z1) * 0.5)
		sm.visible = false
		add_child(sm)
		_smoke.append(sm)


func _process(delta: float) -> void:
	if Sim.world == null:
		return
	var hull := Sim.world.hull
	for i in mini(_water.size(), hull.comps.size()):
		var target: float = hull.comps[i].water * HullState.DECK_HEIGHT
		var w := _water[i]
		w.position.y = lerpf(w.position.y, target, clampf(delta * 3.0, 0.0, 1.0))
		w.visible = w.position.y > 0.01
	var air := Sim.world.air
	for i in mini(_smoke.size(), air.smoke.size()):
		var s: float = air.smoke[i]
		var sm := _smoke[i]
		sm.visible = s > 0.03
		# Thickens downward from the deckhead as it builds.
		sm.scale.y = lerpf(0.4, 2.4, s)
		sm.position.y = GatoInterior.DECK_HEIGHT - 0.5 * sm.scale.y
		(sm.material_override as StandardMaterial3D).albedo_color.a = clampf(s * 0.55, 0.0, 0.5)
	var seen := {}
	for l: Dictionary in hull.leaks:
		_spot("leak", str(l.id), l.p, l.hp, seen)
	for f: Dictionary in hull.fires:
		_spot("fire", str(f.id), f.p, f.size, seen)
	for i in hull.pumps.size():
		_spot("pump", str(i), hull.pumps[i].p, 0.0, seen)
	for key: String in _spots.keys():
		if not seen.has(key):
			_spots[key].queue_free()
			_spots.erase(key)
	for sid: String in interior.stations:
		interior.stations[sid].set_broken(hull.is_broken(sid))


func _spot(kind: String, id: String, p: Vector3, amount: float, seen: Dictionary) -> void:
	var key := kind + ":" + id
	seen[key] = true
	var s: DamageSpot = _spots.get(key)
	if s == null or s.position != p:
		if s != null:
			s.queue_free()
		s = DamageSpot.new().setup(kind, id)
		s.position = p
		add_child(s)
		_spots[key] = s
	s.set_amount(amount)


## Depth of the water (metres above the deck) at interior z, for slowing players.
func water_height_at(z: float) -> float:
	if Sim.world == null or Sim.world.hull.comps.is_empty():
		return 0.0
	var hull := Sim.world.hull
	return hull.comps[hull.comp_at(z)].water * HullState.DECK_HEIGHT
