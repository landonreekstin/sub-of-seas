extends RefCounted
## The PA: what the crew make of what the skipper types.

var runner: Object


func _one(text: String) -> Dictionary:
	var o := CrewCommand.parse(text)
	return o[0] if o.size() == 1 else {"intent": "?%d" % o.size()}


func test_the_examples_from_the_list() -> bool:
	var a := _one("go sink the ship to the east")
	runner.check(a.intent == "attack" and a.target == "" and a.dir.abs == 90.0, "sink the ship to the east")
	var d := _one("dive to the bottom of the ocean")
	runner.check(d.intent == "depth" and d.to == "bottom", "dive to the bottom of the ocean")
	return true


func test_depths() -> bool:
	runner.check(_one("dive to 60").metres == 60.0, "dive to 60")
	runner.check(_one("depth 45 metres").metres == 45.0, "depth 45 metres")
	runner.check(_one("surface").to == "surface", "surface")
	runner.check(_one("periscope depth").to == "periscope", "periscope depth")
	runner.check(_one("Dive! Dive!").to == "dive", "dive dive")
	runner.check(_one("take her deep").to == "deep", "take her deep")
	runner.check(_one("go deeper").change == 20.0, "go deeper")
	return true


func test_courses() -> bool:
	runner.check(_one("come to 090").abs == 90.0, "come to 090")
	runner.check(_one("head north east").abs == 45.0, "head north east")
	runner.check(_one("turn left").rel == -45.0, "turn left")
	runner.check(_one("hard to starboard").rel == 90.0, "hard to starboard")
	runner.check(_one("turn around").rel == 180.0, "turn around")
	runner.check(_one("head for the nearest island").get("island", false), "the nearest island")
	return true


func test_speed() -> bool:
	runner.check(_one("full speed ahead").telegraph == 4, "full speed ahead")
	runner.check(_one("all stop").telegraph == 0, "all stop")
	runner.check(_one("slow down").telegraph == 1, "slow down")
	runner.check(_one("go faster").change == 1, "go faster")
	return true


func test_targets() -> bool:
	runner.check(_one("attack the carrier").target == "carrier", "attack the carrier")
	runner.check(_one("torpedo that destroyer on our port side").dir.rel == -90.0, "port side")
	runner.check(_one("fire torpedoes").intent == "attack", "fire torpedoes")
	runner.check(_one("hit the tanker to the south").dir.abs == 180.0, "hit the tanker to the south")
	return true


func test_the_rest() -> bool:
	var expect := {"get us out of here": "evade", "run silent": "evade", "battle stations": "man_stations", "all hands to stations": "man_stations",
		"stand down": "stand_down", "fix the damage": "fix", "put out the fire": "fix", "what's wrong": "report", "status report": "report",
		"whats our objective": "objective", "what can sonar hear": "contacts", "reload the tubes": "reload", "open fire": "gun",
		"enemy sub": "enemy_sub", "find me an enemy sub": "enemy_sub", "band play the song": "band", "belay that": "cancel"}
	for text: String in expect:
		runner.check(_one(text).intent == expect[text], "\"%s\" means %s (got %s)" % [text, expect[text], _one(text).intent])
	return true


func test_two_orders_in_a_line() -> bool:
	var o := CrewCommand.parse("dive to 60 and come to 090, then full speed")
	runner.check(o.size() == 3 and o[0].intent == "depth" and o[1].intent == "course" and o[2].intent == "speed", "three orders")
	return true


func test_confused() -> bool:
	for text in ["banana", "", "what is the meaning of life", "lets get pizza"]:
		runner.check(CrewCommand.parse(text).is_empty(), "\"%s\" confuses the crew" % text)
	return true
