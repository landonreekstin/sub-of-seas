class_name Diving
## Dive suits (Blaney): a crewman in a suit can stay out on deck while she dives, hold on to the
## grab rails as a lookout, let go and swim, and haul himself back on his lifeline when she
## leaves him behind. He can't come below until she surfaces. The suit goes with the boat's era:
## a hard-hat Mark V on the WWII boats, a Soviet rubber drysuit and mask on the Typhoon, scuba
## on a modern boat. Too deep for it, he blacks out on his lifeline (never dies: there will be
## sea floor exploring later) and comes to once she's shallow enough again.

const SUITS := {
	"ww2": {"name": "hard-hat diving dress", "depth": 90.0},
	"cold_war": {"name": "drysuit and mask", "depth": 150.0},
	"modern": {"name": "scuba gear", "depth": 60.0},
}
const STRAIN_TIME := 15.0 ## s past the suit's depth before he blacks out
const FAR := 15.0 ## m from her hull where the lifeline button shows


static func suit_for(era: String) -> Dictionary:
	return SUITS.get(era, SUITS.ww2)


static func suit() -> Dictionary:
	return suit_for(Game.instance.sub_class.era if Game.instance != null and Game.instance.sub_class != null else "ww2")


static func suited(peer: int) -> bool:
	return Game.instance != null and Game.instance.crew.get("suits", {}).has(peer)


## The sea's surface in deck space (Deck: our own boat's coordinates, waterline at 0): her
## depth while she's dived, as the exterior draws her.
static func water_y() -> float:
	if Sim.world == null:
		return 0.0
	var d := Sim.world.sub.depth
	return d if d > 1.0 else 0.0


## A point in deck space as a sim position (x east, y north): where a diver is in the sea.
static func world_of(sub: SubState, local: Vector3) -> Vector2:
	var h := deg_to_rad(sub.heading)
	var fwd := Vector2(sin(h), cos(h))
	var right := Vector2(cos(h), -sin(h))
	return sub.pos + right * local.x - fwd * local.z


## How fast a still point in the sea moves past the boat, in deck space (she goes forward
## along -z, turns clockwise at `turn_rate`, goes down at `sink` m/s).
static func drift_at(sub: SubState, local: Vector3, sink: float) -> Vector3:
	var w := deg_to_rad(sub.turn_rate)
	return Vector3(w * local.z, sink, -w * local.x + sub.speed)


## Where the boat's phone is: the diver's helmet line comes out at the helm.
static func phone_point() -> Vector3:
	var interior := Game.instance.interior
	if interior == null:
		return Vector3.ZERO
	for id: String in ["helm", "dive"]:
		var s: Node3D = interior.stations.get(id)
		if s != null:
			return s.global_position + Vector3(0, 1.5, 0)
	return interior.spawn_points[0]
