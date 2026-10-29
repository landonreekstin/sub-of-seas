class_name Formations
## Puts groups of ships into the world: a convoy (merchants in columns, escorts on station),
## a task force (capital ships in line ahead behind a destroyer screen), or a hunter-killer
## group (escorts sweeping an area side by side). Host only; everything else is replicated.

const SHIP_DIR := "res://data/ships/%s.tres"
const ESCORT_SPOTS: Array[Vector2] = [ # (right, ahead) of the lead ship
	Vector2(0, 1400), Vector2(-1300, 400), Vector2(1300, 400), Vector2(-1300, -1200),
	Vector2(1300, -1200), Vector2(0, -2200),
]


static func ship_class(key: String) -> ShipClassData:
	return load(SHIP_DIR % key)


## A group from mission data: {type, ships, escorts, pos, course, speed}.
static func spawn(world: OceanWorld, g: Dictionary) -> Array[ShipState]:
	var pos: Vector2 = g.get("pos", Vector2.ZERO)
	var course: float = g.get("course", 0.0)
	var speed: float = g.get("speed", 8.0)
	var ships: Array = g.get("ships", [])
	var escorts: Array = g.get("escorts", [])
	match g.get("type", "convoy"):
		"task_force":
			return task_force(world, pos, course, speed, ships, escorts)
		"hunter_killer":
			return hunter_killer(world, pos, course, ships, g.get("radius", 3000.0))
		_:
			return convoy(world, pos, course, speed, ships, escorts)


## Merchants three abreast, 700 m apart across and 900 m between rows; the first is the lead.
static func convoy(world: OceanWorld, pos: Vector2, course: float, speed: float, merchants: Array, escorts: Array) -> Array[ShipState]:
	var out: Array[ShipState] = []
	var fwd := Vector2(sin(deg_to_rad(course)), cos(deg_to_rad(course)))
	var right := Vector2(fwd.y, -fwd.x)
	var lead: ShipState = null
	for i in merchants.size():
		var col: int = [0, -1, 1][i % 3]
		var row := i / 3
		var offset := Vector2(col * 700.0, -row * 900.0)
		var s := world.add_ship(ship_class(merchants[i]), pos + right * offset.x + fwd * offset.y, course, speed)
		if lead == null:
			lead = s
		else:
			s.leader = lead
			s.station_offset = offset
		out.append(s)
	_screen(world, lead, pos, course, speed, escorts, out)
	return out


## Capital ships in line ahead 1 km apart, destroyers screening ahead and on the bows.
static func task_force(world: OceanWorld, pos: Vector2, course: float, speed: float, capitals: Array, screen: Array) -> Array[ShipState]:
	var out: Array[ShipState] = []
	var fwd := Vector2(sin(deg_to_rad(course)), cos(deg_to_rad(course)))
	var lead: ShipState = null
	for i in capitals.size():
		var s := world.add_ship(ship_class(capitals[i]), pos - fwd * 1000.0 * i, course, speed)
		if lead == null:
			lead = s
		else:
			s.leader = lead
			s.station_offset = Vector2(0, -1000.0 * i)
		out.append(s)
	_screen(world, lead, pos, course, speed, screen, out)
	return out


static func _screen(world: OceanWorld, lead: ShipState, pos: Vector2, course: float, speed: float, escorts: Array, out: Array[ShipState]) -> void:
	var fwd := Vector2(sin(deg_to_rad(course)), cos(deg_to_rad(course)))
	var right := Vector2(fwd.y, -fwd.x)
	for i in escorts.size():
		var spot: Vector2 = ESCORT_SPOTS[i % ESCORT_SPOTS.size()]
		var e := world.add_ship(ship_class(escorts[i]), pos + right * spot.x + fwd * spot.y, course, speed)
		if lead != null:
			world.set_escort(e, lead, spot)
		out.append(e)


## Escorts side by side 1.5 km apart, sweeping a box `radius` around `pos` in long legs.
static func hunter_killer(world: OceanWorld, pos: Vector2, course: float, hunters: Array, radius: float) -> Array[ShipState]:
	var out: Array[ShipState] = []
	var fwd := Vector2(sin(deg_to_rad(course)), cos(deg_to_rad(course)))
	var right := Vector2(fwd.y, -fwd.x)
	for i in hunters.size():
		var lane := (i - (hunters.size() - 1) * 0.5) * 1500.0
		var s := world.add_ship(ship_class(hunters[i]), pos + right * lane, course, 10.0)
		if s.ai != null:
			var legs: Array[Vector2] = []
			for k in 4:
				var along := radius if k % 2 == 0 else -radius
				var across := lane + (k / 2) * radius * 0.5 - radius * 0.25
				legs.append(pos + fwd * along + right * across)
			s.ai.sweep = legs
		out.append(s)
	return out
