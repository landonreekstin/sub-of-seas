class_name Pastimes
extends RefCounted
## The crew's pastimes between watches (Blaney: "more fun things to do in the game and clearer
## ways to access them and see a list"): arm wrestling across the mess table, blackjack against
## the house, the cook's special at the galley range, fishing off the stern. The host keeps the
## games and the crew's bests in crew state; the stations, the deck and the T list draw them.

const ARM: Array[String] = ["arm_a", "arm_b"]
const CARDS: Array[String] = ["cards_1", "cards_2"]
const STATIONS: Array[String] = ["arm_a", "arm_b", "cards_1", "cards_2", "galley"]
const ARM_STEP := 0.04 ## how far one heave moves the hands (1 = pinned)
const ARM_REST := 4.0 ## seconds between bouts
const MEALS: Array[String] = ["burnt to a crisp", "edible, just", "a good square meal", "the best chow in the Pacific Fleet"]
## What bites off the stern in the Pacific: name, lightest and heaviest kg, how often (weight).
const FISH := [["flying fish", 0.2, 0.6, 3], ["skipjack tuna", 2.0, 9.0, 4], ["red snapper", 1.0, 7.0, 3],
	["barracuda", 2.0, 14.0, 2], ["mahi-mahi", 3.0, 16.0, 3], ["grouper", 4.0, 30.0, 2],
	["yellowfin tuna", 10.0, 70.0, 1], ["old boot", 0.6, 0.6, 1]]
const SUITS := ["♠", "♥", "♦", "♣"]
const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]


# --- Arm wrestling -------------------------------------------------------------

## A heave from seat `sid`: `n` presses of Space since the last one.
static func arm_push(crew: Dictionary, sid: String, n: int) -> void:
	var arm: Dictionary = crew.get_or_add("arm", {"pos": 0.0, "on": false, "until": 0.0})
	if not arm.on or sid not in ARM:
		return
	arm.pos = clampf(float(arm.pos) + clampi(n, 0, 6) * ARM_STEP * (1.0 if sid == "arm_b" else -1.0), -1.0, 1.0)


## Runs the bout between whoever sits at the two seats ("" for an empty one). Returns what to
## call out to the boat, or "".
static func arm_step(crew: Dictionary, a: String, b: String, now: float) -> String:
	var arm: Dictionary = crew.get_or_add("arm", {"pos": 0.0, "on": false, "until": 0.0})
	if a == "" or b == "":
		arm.on = false
		arm.pos = 0.0
		return ""
	if not arm.on:
		if now < float(arm.until):
			return ""
		arm.on = true
		arm.pos = 0.0
		arm.a = a
		arm.b = b
		return "Arm wrestling in the mess: %s and %s lock hands. Heave!" % [a, b]
	if absf(float(arm.pos)) < 1.0:
		return ""
	var winner: String = arm.b if float(arm.pos) > 0.0 else arm.a
	var loser: String = arm.a if winner == arm.b else arm.b
	arm.on = false
	arm.until = now + ARM_REST
	var wins: Dictionary = crew.get_or_add("arm_wins", {})
	wins[winner] = int(wins.get(winner, 0)) + 1
	return "%s slams %s's arm to the table! (%d wins)" % [winner, loser, wins[winner]]


# --- Blackjack -----------------------------------------------------------------

## A hand's value, aces counting 11 until that would bust it.
static func hand_value(hand: Array) -> int:
	var total := 0
	var aces := 0
	for c: int in hand:
		var r := c % 13
		if r == 0:
			aces += 1
			total += 11
		else:
			total += mini(r + 1, 10)
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return total


static func card_name(c: int) -> String:
	return RANKS[c % 13] + SUITS[c / 13]


## "deal", "hit" or "stand" at seat `sid` for `who`. Returns what to call out, or "".
static func cards_order(crew: Dictionary, sid: String, key: String, who: String, rng: RandomNumberGenerator) -> String:
	var tables: Dictionary = crew.get_or_add("cards", {})
	var t: Dictionary = tables.get_or_add(sid, {"hand": [], "house": [], "state": "idle", "result": ""})
	match key:
		"deal":
			if t.state == "play":
				return ""
			t.hand = [rng.randi_range(0, 51), rng.randi_range(0, 51)]
			t.house = [rng.randi_range(0, 51)]
			t.state = "play"
			t.result = ""
			if hand_value(t.hand) == 21:
				return _settle(crew, t, who)
		"hit":
			if t.state != "play":
				return ""
			t.hand.append(rng.randi_range(0, 51))
			if hand_value(t.hand) > 21:
				t.state = "done"
				t.result = "BUST"
			elif hand_value(t.hand) == 21:
				return _settle(crew, t, who)
		"stand":
			if t.state != "play":
				return ""
			return _settle(crew, t, who)
	return ""


## The house draws to 17, then the hands are compared.
static func _settle(crew: Dictionary, t: Dictionary, who: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	while hand_value(t.house) < 17:
		t.house.append(rng.randi_range(0, 51))
	var mine := hand_value(t.hand)
	var house := hand_value(t.house)
	t.state = "done"
	if mine == 21 and t.hand.size() == 2:
		t.result = "BLACKJACK!"
	elif house > 21 or mine > house:
		t.result = "YOU WIN"
	elif mine == house:
		t.result = "PUSH"
		return ""
	else:
		t.result = "HOUSE WINS"
		return ""
	var wins: Dictionary = crew.get_or_add("cards_wins", {})
	wins[who] = int(wins.get(who, 0)) + 1
	return "%s beats the house at blackjack%s (%d wins)" % [who, " with a natural!" if t.result == "BLACKJACK!" else "", wins[who]]


# --- The galley ----------------------------------------------------------------

## A meal cooked by `who`, 0 (burnt) .. 3 (perfect). Returns the call-out.
static func meal(crew: Dictionary, who: String, score: int) -> String:
	score = clampi(score, 0, 3)
	var best: Dictionary = crew.get_or_add("meals", {})
	best[who] = maxi(int(best.get(who, -1)), score)
	return "Chow's up! %s's cooking: %s.%s" % [who, MEALS[score], "  The crew cheer!" if score == 3 else ("  The crew groan." if score == 0 else "")]


# --- Fishing -------------------------------------------------------------------

## What took the hook: [kind index, kg].
static func catch_fish(rng: RandomNumberGenerator) -> Array:
	var total := 0
	for f: Array in FISH:
		total += int(f[3])
	var roll := rng.randi_range(0, total - 1)
	for k in FISH.size():
		roll -= int(FISH[k][3])
		if roll < 0:
			return [k, snappedf(rng.randf_range(float(FISH[k][1]), float(FISH[k][2])), 0.1)]
	return [0, 0.3]


## A catch landed by `who`; the host checks it is a fish that could be that size.
static func landed(crew: Dictionary, who: String, kind: int, kg: float) -> String:
	if kind < 0 or kind >= FISH.size() or kg < float(FISH[kind][1]) - 0.05 or kg > float(FISH[kind][2]) + 0.05:
		return ""
	var name: String = FISH[kind][0]
	crew["catches"] = int(crew.get("catches", 0)) + 1
	if name == "old boot":
		return "%s lands... an old boot. The crew are delighted." % who
	var best: Dictionary = crew.get_or_add("fish", {})
	var was: Array = best.get(who, ["", 0.0])
	if kg > float(was[1]):
		best[who] = [name, kg]
	return "%s lands a %.1f kg %s off the stern! Into the galley with it." % [who, kg, name]
