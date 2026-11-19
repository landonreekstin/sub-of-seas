class_name CrewCommand
extends RefCounted
## What the skipper means by a line typed into the PA (Blaney: "go sink the ship to the east",
## "dive to the bottom of the ocean": it knows what you mean). No rendering, no world: words in,
## orders out, so it is unit-tested. BotCrew carries the orders out. To teach the crew something
## new, add a line to `_clause` and a case to BotCrew._carry_out.

const COMPASS := {"north": 0.0, "northeast": 45.0, "east": 90.0, "southeast": 135.0, "south": 180.0,
	"southwest": 225.0, "west": 270.0, "northwest": 315.0}
## Words for each kind of target; "" is any ship at all.
const TARGETS := {"freighter": "freighter", "freighters": "freighter", "cargo": "freighter", "merchant": "merchant", "merchantman": "merchant",
	"tanker": "tanker", "oiler": "tanker", "carrier": "carrier", "flattop": "carrier", "battleship": "battleship", "cruiser": "cruiser",
	"destroyer": "destroyer", "tincan": "destroyer", "escort": "escort", "frigate": "frigate", "kaibokan": "kaibokan", "chaser": "subchaser", "subchaser": "subchaser",
	"sub": "sub", "submarine": "sub", "boat": "sub"}
## Words for the things in the depths (Monster.KINDS); "" is any of them.
const MONSTERS := {"monster": "", "monsters": "", "creature": "", "beast": "", "leviathan": "", "kraken": "squid", "squid": "squid",
	"anglerfish": "angler", "angler": "angler", "serpent": "serpent", "eel": "serpent", "megalodon": "megalodon", "megladon": "megalodon",
	"meg": "megalodon", "shark": "megalodon"}
const ATTACK := ["sink", "attack", "torpedo", "kill", "destroy", "hit", "engage", "shoot", "blow", "fire", "get", "target", "take"]
const SPEEDS := {"stop": 0, "halt": 0, "reverse": -1, "back": -1, "slow": 1, "quiet": 1, "half": 2, "standard": 3, "cruise": 3, "full": 4, "flank": 4, "fast": 4, "maximum": 4, "max": 4}

## Every kind of order, with lines that say it (Blaney: "make a long list of all PA commands"):
## shown on the PA panel, written out in docs/pa_commands.md, and each line is checked by the
## tests to mean what it says here. Each: [heading, [[line, intent], ...]].
const HELP := [
	["Moving", [["full speed", "speed"], ["slow ahead", "speed"], ["stop", "speed"], ["back", "speed"], ["faster", "speed"], ["slower", "speed"],
		["come to 090", "course"], ["head north", "course"], ["turn left", "course"], ["hard right", "course"], ["turn around", "course"], ["head for the island", "course"]]],
	["Up and down", [["dive", "depth"], ["dive to 60", "depth"], ["periscope depth", "depth"], ["take her deep", "depth"], ["go deeper", "depth"], ["go up", "depth"],
		["dive to the bottom", "depth"], ["surface", "depth"], ["crash surface", "depth"]]],
	["Fighting", [["sink the ship to the east", "attack"], ["attack the carrier", "attack"], ["sink the destroyer to the north", "attack"], ["fire torpedoes", "attack"],
		["reload", "reload"], ["open fire", "gun"], ["enemy sub", "enemy_sub"], ["attack the enemy sub", "enemy_sub"], ["belay that", "cancel"]]],
	["Getting away", [["get us out of here", "evade"], ["evade", "evade"], ["silent running", "evade"]]],
	["The crew", [["battle stations", "man_stations"], ["all hands on deck", "all_hands"], ["take us through the cave", "cave"], ["fix the damage", "fix"],
		["pump out the water", "fix"], ["fresh air", "air"], ["stand down", "stand_down"]]],
	["Places to go", [["take us to the wreck", "goto"], ["go to the ruins", "goto"], ["explore the vents", "goto"], ["visit the garden", "goto"],
		["take us to the crystal city", "goto"], ["go to the island", "goto"], ["take us to the cave", "goto"], ["list places", "places"], ["clear the waypoint", "goto"]]],
	["Asking", [["report", "report"], ["what's out there", "contacts"], ["what's our objective", "objective"]]],
	["For fun", [["god mode", "god"], ["god mode off", "god"], ["band play", "band"], ["stop the music", "band"], ["spawn a kraken", "monster"], ["megalodon", "monster"], ["sea serpent", "monster"]]],
]


## The orders in a line, in the order given. Each is {intent, ...}; a line we can make nothing of
## gives none, and the crew say so.
static func parse(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var clean := _clean(text)
	for part in clean.replace(" and then ", ",").replace(" then ", ",").replace(" and ", ",").replace(" also ", ",").split(",", false):
		var c := _clause(" %s " % part.strip_edges())
		if not c.is_empty():
			out.append(c)
	return out


static func _clean(text: String) -> String:
	var t := text.to_lower().replace("'", "").replace("-", " ")
	var kept := ""
	for ch in t:
		kept += ch if ch == "," or ch == ";" or ch == " " or ch.is_valid_int() or (ch >= "a" and ch <= "z") else " "
	kept = kept.replace(";", ",")
	for pair: Array in [["north east", "northeast"], ["north west", "northwest"], ["south east", "southeast"], ["south west", "southwest"],
			["sub chaser", "subchaser"], ["tin can", "tincan"], ["flat top", "flattop"], ["u boat", "sub"], ["uboat", "sub"]]:
		kept = kept.replace(pair[0], pair[1])
	while "  " in kept:
		kept = kept.replace("  ", " ")
	return kept.strip_edges()


static func _has(c: String, words: Array) -> bool:
	for w: String in words:
		if " %s " % w in c:
			return true
	return false


## The kind of place a line names (Places.WORDS), or "".
static func _place(c: String) -> String:
	for w: String in Places.WORDS:
		if " %s " % w in c:
			return Places.WORDS[w]
	return ""


static func _number(c: String) -> int:
	var m := RegEx.create_from_string("\\b(\\d{1,4})\\b").search(c)
	return int(m.get_string(1)) if m != null else -1


## {abs: bearing} or {rel: degrees off the bow}, or empty.
static func _direction(c: String) -> Dictionary:
	for w: String in COMPASS:
		if " %s " % w in c:
			return {"abs": COMPASS[w]}
	if _has(c, ["ahead", "front", "bow"]):
		return {"rel": 0.0}
	if _has(c, ["behind", "astern", "stern"]):
		return {"rel": 180.0}
	if _has(c, ["left", "port"]):
		return {"rel": -90.0}
	if _has(c, ["right", "starboard"]):
		return {"rel": 90.0}
	return {}


static func _clause(c: String) -> Dictionary:
	if " god " in c or " godmode " in c: # "god mode" (Blaney): super speed, super swimming, can't be knocked out
		return {"intent": "god", "off": _has(c, ["off", "stop", "end", "disable", "no"]), "toggle": not _has(c, ["on", "off", "stop", "end", "disable", "no", "enable"])}
	# Places to go (Blaney: waypoints from the PA): "take us to the wreck", "go to the island".
	if _has(c, ["waypoint", "waypoints"]) and _has(c, ["clear", "cancel", "remove", "delete", "forget"]):
		return {"intent": "goto", "clear": true}
	if _has(c, ["places", "destinations", "sights"]) or " where can we go " in c:
		return {"intent": "places"}
	var place := _place(c)
	if place != "" and not " through " in c and _has(c, ["go", "take", "travel", "navigate", "waypoint", "visit", "explore", "sail", "bring", "find", "see", "course", "head", "make"]) \
			and not (place == "island" and _has(c, ["head", "course", "turn", "steer"]) and not _has(c, ["go", "take", "travel", "visit", "explore", "waypoint"])):
		return {"intent": "goto", "place": place}
	if _has(c, ["cave", "caves", "tunnel"]): # "take us through the cave" (Blaney: be aboard while the crew do it)
		return {"intent": "cave"}
	if " all hands " in c and not _has(c, ["stand", "down"]): # "all hands on deck": fill the boat and work the objective
		return {"intent": "all_hands"}
	if " slow down " in c:
		return {"intent": "speed", "telegraph": 1}
	if _has(c, ["evade", "escape", "flee", "run", "hide", "silent"]) or " get away " in c or " lose them " in c or " out of here " in c:
		return {"intent": "evade"}
	if " enemy sub " in c or " enemy submarine " in c:
		return {"intent": "enemy_sub", "attack": _has(c, ATTACK)}
	for w: String in MONSTERS: # "spawn a kraken": something comes up out of the deep for us (Blaney)
		if " %s " % w in c:
			return {"intent": "monster", "kind": MONSTERS[w]}
	if _has(c, ["play", "music", "song", "band", "concert"]):
		return {"intent": "band", "off": _has(c, ["stop", "quit", "enough"])}
	if _has(c, ["cease", "cancel", "belay", "abort", "nevermind"]):
		return {"intent": "cancel"}
	if _has(c, ["objective", "mission", "orders"]) or " what are we doing " in c:
		return {"intent": "objective"}
	if _has(c, ["status", "report", "wrong", "damage", "contacts", "contact", "situation", "out there", "hear"]) and not _has(c, ["fix", "repair"]):
		return {"intent": "contacts" if _has(c, ["contact", "contacts", "sonar", "hear"]) or " out there " in c else "report"}
	if _has(c, ["fix", "repair", "patch", "weld", "mend", "extinguish"]) or " put out " in c or " pump " in c:
		return {"intent": "fix"}
	if _has(c, ["reload"]):
		return {"intent": "reload"}
	if " open fire " in c or _has(c, ["gun"]):
		return {"intent": "gun"}
	for w: String in TARGETS:
		if " %s " % w in c and (_has(c, ATTACK) or _has(c, ["find", "after", "hunt", "chase"])):
			return {"intent": "attack", "target": TARGETS[w], "dir": _direction(c)}
	if _has(c, ["ship", "ships", "target", "enemy", "enemies", "him", "them", "it", "something"]) and _has(c, ATTACK + ["find", "after", "hunt", "chase"]):
		return {"intent": "attack", "target": "", "dir": _direction(c)}
	if _has(c, ["fire", "torpedo", "torpedoes", "attack", "sink"]):
		return {"intent": "attack", "target": "", "dir": _direction(c)}
	if _has(c, ["battle", "stations", "hands", "crew", "man", "spawn"]) and not _has(c, ["stand", "down"]):
		return {"intent": "man_stations"}
	if " stand down " in c or " at ease " in c or _has(c, ["dismissed", "dismiss"]):
		return {"intent": "stand_down"}
	if _has(c, ["air", "oxygen", "scrubber", "co2", "breathe"]):
		return {"intent": "air"}
	var depth := _depth(c)
	if not depth.is_empty():
		return depth
	var course := _course(c)
	if not course.is_empty():
		return course
	for w: String in SPEEDS:
		if " %s " % w in c:
			return {"intent": "speed", "telegraph": SPEEDS[w]}
	if _has(c, ["faster", "speed"]):
		return {"intent": "speed", "change": 1}
	if _has(c, ["slower"]):
		return {"intent": "speed", "change": -1}
	return {}


static func _depth(c: String) -> Dictionary:
	if _has(c, ["surface", "emerge", "breach"]) and _has(c, ["crash", "emergency", "breach"]):
		return {"intent": "depth", "to": "crash"}
	if _has(c, ["surface", "emerge"]):
		return {"intent": "depth", "to": "surface"}
	if _has(c, ["periscope", "scope"]):
		return {"intent": "depth", "to": "periscope"}
	if _has(c, ["bottom", "floor", "seabed"]):
		return {"intent": "depth", "to": "bottom"}
	if " go up " in c or _has(c, ["shallower", "rise", "climb"]):
		return {"intent": "depth", "change": -20.0}
	if " go down " in c or _has(c, ["deeper"]):
		return {"intent": "depth", "change": 20.0}
	if _has(c, ["dive", "depth", "submerge", "deep", "down"]):
		var n := _number(c)
		if n >= 0:
			return {"intent": "depth", "metres": float(n)}
		return {"intent": "depth", "to": "deep" if _has(c, ["deep", "test"]) else "dive"}
	return {}


static func _course(c: String) -> Dictionary:
	var dir := _direction(c)
	var turning := _has(c, ["turn", "come", "head", "steer", "go", "course", "bear", "hard", "sail", "move", "around"])
	if _has(c, ["around"]) and _has(c, ["turn", "come", "go", "head"]) or " come about " in c:
		return {"intent": "course", "rel": 180.0}
	if _has(c, ["island", "land"]) and turning:
		return {"intent": "course", "island": true}
	var n := _number(c)
	if dir.has("abs") and turning or dir.has("abs") and n < 0:
		return {"intent": "course", "abs": dir.abs}
	if dir.has("rel") and turning and dir.rel != 0.0:
		var by := float(n) if n > 0 else (90.0 if _has(c, ["hard"]) else 45.0)
		return {"intent": "course", "rel": signf(dir.rel) * by if dir.rel != 180.0 else 180.0}
	if n >= 0 and n <= 360 and _has(c, ["course", "come", "steer", "head", "bearing", "heading", "turn"]):
		return {"intent": "course", "abs": float(n)}
	return {}
