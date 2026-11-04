class_name ChartKnown
extends RefCounted
## What the boat has actually seen of the map in an enemy-sub fight (Blaney: "your map cannot
## show the sub, only the map around your sub given the equipment you have"). A grid of what's
## been looked at: by eye (surfaced, or the raised scope: clear pictures) or by sonar (dived,
## the echo sounder's small patch, a ping's bigger one: dotted, depths only). Every peer works it
## out from the same replicated state; a joiner is sent the host's copy.

const CELL := 250.0
const CELLS := 240 ## a side: 60 km around where the fight began
const SONAR := 1
const SIGHT := 2
const SOUNDER_RANGE := 700.0
const PING_RANGE := 3500.0
const SURFACE_SIGHT := 6000.0
const SCOPE_SIGHT := 4000.0

var origin := Vector2.ZERO ## the grid's south-west corner
var grid := PackedByteArray()
var version := 0


func start(centre: Vector2) -> void:
	origin = centre - Vector2.ONE * CELL * CELLS * 0.5
	grid.resize(CELLS * CELLS)
	grid.fill(0)
	version += 1


func at(p: Vector2) -> int:
	if grid.is_empty():
		return 0
	var c := Vector2i(((p - origin) / CELL).floor())
	if c.x < 0 or c.y < 0 or c.x >= CELLS or c.y >= CELLS:
		return 0
	return grid[c.y * CELLS + c.x]


func reveal(centre: Vector2, radius: float, kind: int) -> void:
	if grid.is_empty():
		return
	var r := ceili(radius / CELL)
	var c := Vector2i(((centre - origin) / CELL).floor())
	var changed := false
	for j in range(maxi(c.y - r, 0), mini(c.y + r + 1, CELLS)):
		for i in range(maxi(c.x - r, 0), mini(c.x + r + 1, CELLS)):
			if Vector2(i - c.x, j - c.y).length_squared() > r * r:
				continue
			var k := j * CELLS + i
			if grid[k] & kind == 0:
				grid[k] |= kind
				changed = true
	if changed:
		version += 1


## What this boat can see this moment: once a second or so.
func sweep(world: OceanWorld) -> void:
	var sub := world.sub
	var sight := world.conditions.visual_between(sub.pos, sub.pos)
	if sub.is_surfaced():
		reveal(sub.pos, SURFACE_SIGHT * sight, SIGHT)
	elif sub.scope_height() > 0.0:
		reveal(sub.pos, SCOPE_SIGHT * sight, SIGHT)
	reveal(sub.pos, SOUNDER_RANGE, SONAR)
