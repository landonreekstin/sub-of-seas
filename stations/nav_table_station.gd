class_name NavTableStation
extends Station
## The sand table in the navigation room (Blaney: "a navigation room that shows the whole
## terrain of the region that we are exploring in a topographical map on a table"): a raised
## model of the patrol's sea floor and islands from the seabed, land standing up green and
## brown, shallows pale, the deep dark, under a clear sheet of "sea", with a brass boat that
## moves and turns with ours. Rebuilt when the seabed changes or we sail off the edge of it.
## E stands over it for a closer look.

const SIZE := 1.5 ## m, the model's side
const TOP := 0.92 ## m, the table's sea level above the deck
const GRID := 96 ## cells a side
const LAND_SCALE := 0.22 ## m of model for the highest peak
const DEEP_SCALE := 0.12 ## m of model for the deep ocean floor

var _relief: MeshInstance3D
var _boat: Node3D
var _built_version := -1
var _area := Rect2() ## the sim area the model shows (x east, y north, m)
var _scale_label: Label3D


func _ready() -> void:
	# The table: a wooden frame on legs with a raised rim.
	var wood := Color("#6B4A2E")
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			Build.box(self, Vector3(0.08, TOP - 0.12, 0.08), Vector3(x * (SIZE * 0.5 + 0.05), (TOP - 0.12) * 0.5, z * (SIZE * 0.5 + 0.05)), wood, false)
	Build.box(self, Vector3(SIZE + 0.2, 0.06, SIZE + 0.2), Vector3(0, TOP - 0.16, 0), wood, false)
	for side in [-1.0, 1.0]:
		Build.box(self, Vector3(SIZE + 0.24, 0.24, 0.06), Vector3(0, TOP - 0.04, side * (SIZE * 0.5 + 0.1)), wood, false)
		Build.box(self, Vector3(0.06, 0.24, SIZE + 0.24), Vector3(side * (SIZE * 0.5 + 0.1), TOP - 0.04, 0), wood, false)
	Build.hitbox(self, Vector3(SIZE + 0.24, TOP + 0.1, SIZE + 0.24), Vector3(0, (TOP + 0.1) * 0.5, 0))
	_relief = MeshInstance3D.new()
	_relief.position.y = TOP
	add_child(_relief)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	_relief.material_override = mat
	# The sea: a clear blue sheet at sea level.
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(SIZE, SIZE)
	sea.mesh = pm
	sea.position.y = TOP + 0.002
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.35, 0.65, 0.85, 0.28)
	sm.roughness = 0.1
	sea.material_override = sm
	add_child(sea)
	# Our boat in brass, and the compass rose and scale on the rim.
	_boat = Node3D.new()
	add_child(_boat)
	var hull := Build.sphere(_boat, 0.02, Vector3.ZERO, Color("#C9A04A"), 0.4)
	hull.scale = Vector3(0.6, 0.5, 2.4)
	Build.box(_boat, Vector3(0.012, 0.02, 0.016), Vector3(0, 0.012, -0.004), Color("#C9A04A"), false)
	var n := Build.label(self, "N ↑", Vector3(0, TOP + 0.1, -(SIZE * 0.5 + 0.1)), 28, UiKit.BRASS)
	n.rotation.x = -PI / 2.0
	_scale_label = Build.label(self, "", Vector3(0, TOP + 0.1, SIZE * 0.5 + 0.1), 18, UiKit.CREAM)
	_scale_label.rotation.x = -PI / 2.0
	set_view(Vector3(0, TOP + 1.05, SIZE * 0.62), Vector3(0, TOP, -0.05))


func _process(_delta: float) -> void:
	if Sim.world == null:
		return
	var sub := Sim.world.sub
	var seabed := Sim.world.seabed
	var inside := _area.grow(-_area.size.x * 0.06).has_point(sub.pos)
	if seabed.version != _built_version or not inside:
		_build(seabed, sub.pos)
	var at := _to_table(sub.pos)
	_boat.position = Vector3(at.x, TOP + 0.012, at.y)
	_boat.rotation.y = -deg_to_rad(sub.heading)


## Sim plane -> the table's local x, z (north is -z, as everywhere).
func _to_table(p: Vector2) -> Vector2:
	var u := (p - _area.position) / _area.size
	return Vector2((u.x - 0.5) * SIZE, (0.5 - u.y) * SIZE)


## The area to show: every feature's footprint and the boat, squared up, at least 16 km.
func _bounds(seabed: Seabed, boat: Vector2) -> Rect2:
	var r := Rect2(boat, Vector2.ZERO)
	for f: Dictionary in seabed.features:
		var reach := float(f.r) * float(f.stretch) * 1.6
		r = r.expand(Vector2(f.x, f.y) + Vector2(reach, reach)).expand(Vector2(f.x, f.y) - Vector2(reach, reach))
	var side := maxf(maxf(r.size.x, r.size.y) * 1.08, 16000.0)
	return Rect2(r.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))


func _build(seabed: Seabed, boat: Vector2) -> void:
	_built_version = seabed.version
	_area = _bounds(seabed, boat)
	_scale_label.text = "the patrol area, %d km across" % roundi(_area.size.x / 1000.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cell := SIZE / GRID
	var h := []
	for j in GRID + 1:
		var row := []
		for i in GRID + 1:
			var p := _area.position + Vector2(i, GRID - j) * (_area.size.x / GRID)
			row.append(seabed.floor_depth(p))
		h.append(row)
	for j in GRID:
		for i in GRID:
			var quad := [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				for k: int in tri:
					var q: Vector2i = quad[k]
					var d: float = h[q.y][q.x]
					st.set_color(_colour(d))
					st.add_vertex(Vector3(-SIZE * 0.5 + q.x * cell, _height(d), -SIZE * 0.5 + q.y * cell))
	st.generate_normals()
	_relief.mesh = st.commit()


## Model height for a floor depth (negative depth is land).
static func _height(depth: float) -> float:
	if depth < 0.0:
		return minf(-depth, 300.0) / 300.0 * LAND_SCALE
	return -sqrt(minf(depth, Seabed.BASE) / Seabed.BASE) * DEEP_SCALE - 0.004


static func _colour(depth: float) -> Color:
	if depth < -120.0:
		return Color("#8A7A62").lerp(Color("#B8B0A0"), clampf((-depth - 120.0) / 140.0, 0.0, 1.0)) # rock to bare peaks
	if depth < -4.0:
		return Color("#4E8A3A").lerp(Color("#3F6B30"), clampf(-depth / 120.0, 0.0, 1.0)) # jungle
	if depth < 0.0:
		return Color("#E2D3A0") # beach
	if depth < 20.0:
		return Color("#9FE0D8") # reef shallows
	return Color("#4FA3C4").lerp(Color("#0F2C4A"), clampf(sqrt(depth / Seabed.BASE), 0.0, 1.0))


func _build_overlay(root: Control) -> void:
	var box := UiKit.bottom_panel(root)
	box.add_child(UiKit.label("SAND TABLE — the whole patrol area. Brass boat: us. Green: land; pale: reefs and shallows; dark: deep water.", 18))
	box.add_child(UiKit.label("[Q] step back", 16, UiKit.DIM))
