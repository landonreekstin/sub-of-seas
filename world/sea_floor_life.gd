class_name SeaFloorLife
extends Node3D
## The sea floor round the boat, alive (Blaney: "make this seafloor more interesting and the
## ocean feel more alive"; "make sure we do a good job of optimization, this game can't be
## laggy"): rocks, tube sponges, starfish, shells and crabs on the bottom, sea grass in the
## shallows and tall swaying kelp a bit deeper. Laid out in square tiles round the boat, the
## same every time for the same patch of sea (seeded by the tile), each kind of thing in a tile
## one MultiMesh (one draw call), faded out past what the water lets you see, and at most one
## tile built a frame. The kelp and grass sway in their shader, so nothing here costs a frame.

const TILE := 100.0 ## m a side
const KEEP := 1 ## tiles each way round the boat's own (3 x 3)
const DRAWN := 260.0 ## m: no floor deeper than the terrain draws (TerrainView.DEEPEST_DRAWN)
const SEE := 170.0 ## m: drawn out to here, the most the clearest water shows

## kind: [count a tile, shallowest, deepest floor (m), size min, max, colours]
const KINDS := {
	"rock": [36, 0.0, DRAWN, 0.5, 2.6, [Color("#6F6B60"), Color("#5B5A55"), Color("#7C7466")]],
	"sponge": [22, 6.0, DRAWN, 0.4, 1.4, [Color("#E08A2E"), Color("#D9C24A"), Color("#8F5BC4"), Color("#C9D6D6")]],
	"starfish": [26, 0.0, 160.0, 0.18, 0.4, [Color("#E8662E"), Color("#C93B3B"), Color("#3E7FD0"), Color("#E8A23A")]],
	"shell": [24, 0.0, 120.0, 0.12, 0.3, [Color("#EADCC0"), Color("#E7B9B0"), Color("#D8CFC4")]],
	"crab": [10, 0.0, 120.0, 0.25, 0.5, [Color("#C2452D"), Color("#D97A35"), Color("#8E3A2A")]],
	"grass": [140, 0.0, 22.0, 0.5, 1.2, [Color("#5E9A3E"), Color("#7AAE4A"), Color("#4C8A47")]],
	"kelp": [55, 8.0, 45.0, 6.0, 14.0, [Color("#6E6A2A"), Color("#7C7A35"), Color("#5C6A2C")]],
}

var _tiles := {} ## Vector2i -> Node3D
var _meshes := {}
var _mats := {}
var built := 0 ## tiles built so far (tests)
var _version := -1
var _pending: Array = [] ## [tile, kind]: what's left to build, one a frame (no hitch when she moves on)


func _ready() -> void:
	var rock := SphereMesh.new()
	rock.radius = 0.5
	rock.height = 0.7
	rock.radial_segments = 7
	rock.rings = 4
	var shell := SphereMesh.new()
	shell.radius = 0.5
	shell.height = 0.4
	shell.is_hemisphere = true
	shell.radial_segments = 8
	shell.rings = 3
	_meshes = {"rock": rock, "sponge": Creatures.sponge_mesh(), "starfish": Creatures.starfish_mesh(), "shell": shell,
		"crab": Creatures.crab_mesh(), "grass": Creatures.grass_mesh(), "kelp": Creatures.kelp_mesh()}
	var toon := Creatures.creature_mat()
	var stone := (Build.mat(Color.WHITE, 0.0, "rock") as ShaderMaterial).duplicate() as ShaderMaterial
	stone.set_shader_parameter("vertex_color", true)
	var sway := ShaderMaterial.new()
	sway.shader = preload("res://world/sway.gdshader")
	var tall := sway.duplicate() as ShaderMaterial
	tall.set_shader_parameter("sway", 0.08) # 1 m model scaled to 10 m: the bend is per model metre
	tall.set_shader_parameter("speed", 0.5)
	_mats = {"rock": stone, "grass": sway, "kelp": tall}
	for k: String in KINDS:
		if not _mats.has(k):
			_mats[k] = toon


## Each frame: drop tiles left behind, build the nearest missing one.
func sync(sub_pos: Vector2, seabed: Seabed) -> void:
	if seabed.version != _version:
		_version = seabed.version
		clear()
	var here := Vector2i(floori(sub_pos.x / TILE), floori(sub_pos.y / TILE))
	for t: Vector2i in _tiles.keys():
		if absi(t.x - here.x) > KEEP + 1 or absi(t.y - here.y) > KEEP + 1: # a tile of slack, so she can wander on an edge
			_tiles[t].queue_free()
			_tiles.erase(t)
	while not _pending.is_empty():
		var job: Array = _pending.pop_front()
		if _tiles.has(job[0]) and is_instance_valid(_tiles[job[0]]):
			_build_kind(_tiles[job[0]], job[0], job[1], seabed)
			return
	for r in KEEP + 1:
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := here + Vector2i(dx, dy)
				if not _tiles.has(t):
					var node := Node3D.new()
					add_child(node)
					_tiles[t] = node
					built += 1
					var origin := Vector2(t) * TILE
					# Open ocean far below anything drawn has nothing.
					if seabed.floor_depth(origin + Vector2.ONE * TILE * 0.5) > DRAWN + 120.0 and seabed.floor_depth(origin) > DRAWN + 120.0:
						return
					for kind: String in KINDS:
						_pending.append([t, kind])
					return


func clear() -> void:
	for t: Vector2i in _tiles:
		_tiles[t].queue_free()
	_tiles.clear()
	_pending.clear()


## One kind of thing in tile `t`, as one MultiMesh under `node`.
func _build_kind(node: Node3D, t: Vector2i, kind: String, seabed: Seabed) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([t.x, t.y, seabed.version, kind])
	var origin := Vector2(t) * TILE
	var k: Array = KINDS[kind]
	var xforms: Array[Transform3D] = []
	var colours: Array[Color] = []
	var cols: Array = k[5]
	for i in int(k[0]):
		var p := origin + Vector2(rng.randf(), rng.randf()) * TILE
		var d := seabed.floor_depth(p, true)
		var s := rng.randf_range(k[3], k[4])
		var tint := rng.randf_range(-0.06, 0.06)
		var c: Color = cols[rng.randi() % cols.size()]
		if d < float(k[1]) or d > float(k[2]) or d < 0.5:
			continue
		var b := Basis(Vector3.UP, rng.randf() * TAU)
		match kind:
			"rock":
				b = b.scaled(Vector3(s * rng.randf_range(0.8, 1.4), s * rng.randf_range(0.5, 0.9), s * rng.randf_range(0.8, 1.4)))
			"kelp": # a tall frond, a little wider than deep so the blades read
				b = b.scaled(Vector3(s * 0.9, s, s * 0.9))
			_:
				b = b.scaled(Vector3.ONE * s)
		var y := -d - (s * 0.15 if kind == "rock" else 0.05)
		xforms.append(Transform3D(b, Vector3(p.x, y, -p.y)))
		colours.append(Color(c.r + tint, c.g + tint, c.b + tint * 0.5))
		if kind == "kelp" and rng.randf() < 0.7: # kelp grows in stands
			for j in rng.randi_range(2, 5):
				var q := p + Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(-2.5, 2.5))
				var dq := seabed.floor_depth(q, true)
				var sq := rng.randf_range(k[3], k[4])
				xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sq * 0.9, sq, sq * 0.9)), Vector3(q.x, -dq - 0.05, -q.y)))
				colours.append(c.darkened(rng.randf() * 0.15))
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _meshes[kind]
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colours[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _mats[kind]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = SEE + TILE * 0.71 # from the tile's middle: past what any water shows
	mi.name = kind
	node.add_child(mi)
