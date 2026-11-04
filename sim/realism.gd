class_name Realism
## How arcadey or realistic a patrol plays (lando, M9: modes on an arcade ↔ realism scale).
## The host picks it; it sets the sim's knobs. Arcade is the game as it has always played.

const KEYS := ["arcade", "standard", "realistic"]

const LEVELS := {
	"arcade": {
		"title": "Arcade", "handling": 1.0, "dud_chance": 0.05, "damage": 1.0, "air": 1.0, "escorts": 1.0,
		"torpedo_speed": 2.0, "tdc": false,
		"blurb": "A lively boat, fast torpedoes straight out of the bow (point her at the scope's mark and fire), forgiving damage and air.",
	},
	"standard": {
		"title": "Standard", "handling": 0.5, "dud_chance": 0.12, "damage": 1.25, "air": 1.2, "escorts": 1.15,
		"torpedo_speed": 1.0, "tdc": true,
		"blurb": "Between the two: a heavier boat, more duds, leaks and fires that get away faster.",
	},
	"realistic": {
		"title": "Realistic", "handling": 0.0, "dud_chance": 0.25, "damage": 1.6, "air": 1.4, "escorts": 1.3,
		"torpedo_speed": 1.0, "tdc": true,
		"blurb": "The real boat's handling, 1942's Mark 14 (one in four a dud), fast flooding, foul air, sharp escorts.",
	},
}


static func level(key: String) -> Dictionary:
	return LEVELS.get(key, LEVELS.arcade)


## Sets `world`'s knobs for this level.
static func apply(world: OceanWorld, key: String) -> void:
	var l := level(key)
	world.realism = key if LEVELS.has(key) else "arcade"
	world.sub.handling = l.handling
	world.dud_chance = l.dud_chance
	world.hull.harshness = l.damage
	world.air.harshness = l.air
	world.escort_sharpness = l.escorts
	world.torpedo_speed = Torpedo.SPEED * float(l.torpedo_speed)


## Whether this level aims with the TDC and gyros (Blaney: Arcade just points the bow).
static func uses_tdc(key: String) -> bool:
	return bool(level(key).tdc)
