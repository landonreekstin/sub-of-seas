class_name Wrestling
extends RefCounted
## Wrestling on the aft deck (Blaney: "wrestle the other person into the water ... like a
## simplified version of Your Only Move Is HUSTLE where only Greco-Roman wrestling moves are
## allowed"). Two crewmen step into the ring painted across the aft casing; each turn both pick
## a move in secret, then the two play out together. The clinch slides athwartships, toward
## one man's edge or the other's; whoever is driven past his edge goes in the sea.
## Greco-Roman: upper body only, no grabbing below the waist, no trips.
##
## Host-run on the crew state (`crew.wrestle`), so everyone sees the same bout:
##   {a, b: peer ids (a's edge is port, -x; b's starboard, +x), pos: the clinch, m from the
##    centreline (+ toward b's edge), phase: "count" | "choose" | "show" | "done",
##    until: sim time the phase ends, moves: {a, b}, lock: who holds a body lock (0 nobody),
##    off: who is off balance (0 nobody), last: what happened, winner}

const MOVES := ["push", "drag", "lock", "suplex", "brace"]
const NAMES := {"push": "Push", "drag": "Arm drag", "lock": "Body lock", "suplex": "Suplex", "brace": "Brace"}
const KEYS := {KEY_1: "push", KEY_2: "drag", KEY_3: "lock", KEY_4: "suplex", KEY_5: "brace"}
const COUNT_TIME := 3.0 ## s from both stepping in to the first turn
const CHOOSE_TIME := 8.0 ## s to pick; no pick braces
const SHOW_TIME := 2.2 ## s the turn plays out before the next
const DONE_TIME := 4.0 ## s the result stays up
const GAP := 0.35 ## m each man stands off the clinch


static func new_bout(a: int, b: int, now: float) -> Dictionary:
	return {"a": a, "b": b, "start": now, "pos": 0.0, "phase": "count", "until": now + COUNT_TIME, "moves": {},
		"lock": 0, "off": 0, "last": "", "winner": 0}


## One turn: what `ma` (a's move) and `mb` (b's) do to the bout. Returns the change:
## {shift: m the clinch moves (+ toward b's edge), lock, off: who holds a lock / is off balance
## after it, text}. The off-balance man is moved twice as far.
static func resolve(bout: Dictionary, ma: String, mb: String, name_a: String, name_b: String) -> Dictionary:
	var a: int = bout.a
	var b: int = bout.b
	var r := {"shift": 0.0, "lock": 0, "off": 0, "text": ""}
	var held: int = bout.lock
	# Score it from a's side, then mirror for b.
	var one := _duel(ma, mb, held == a, held == b)
	var two := _duel(mb, ma, held == b, held == a)
	var gain: float = one.gain - two.gain # + drives b back
	r.shift = gain
	if one.lock:
		r.lock = a
	elif two.lock:
		r.lock = b
	elif held != 0 and not one.breaks and not two.breaks and ma != "suplex" and mb != "suplex":
		r.lock = held # a lock is kept until it is used or broken
	if one.unbalances:
		r.off = b
	elif two.unbalances:
		r.off = a
	if one.self_off:
		r.off = a
	elif two.self_off:
		r.off = b
	var off: int = bout.off
	if off == b and r.shift > 0.0 or off == a and r.shift < 0.0:
		r.shift *= 2.0
	var say_a: String = one.say.replace("{me}", name_a).replace("{them}", name_b)
	var say_b: String = two.say.replace("{me}", name_b).replace("{them}", name_a)
	var said := say_a if (one.gain >= two.gain and say_a != "") or say_b == "" else say_b
	r.text = "%s: %s   —   %s: %s\n%s" % [name_a, NAMES[ma], name_b, NAMES[mb], said]
	return r


## How far `mine` drives the other man back against `theirs` (>= 0), and what it sets up.
static func _duel(mine: String, theirs: String, i_hold: bool, they_hold: bool) -> Dictionary:
	var d := {"gain": 0.0, "lock": false, "breaks": false, "unbalances": false, "self_off": false, "say": ""}
	match mine:
		"push":
			match theirs:
				"push":
					d.gain = 0.15
					d.say = "Chest to chest, neither gives an inch."
				"brace":
					d.gain = 0.2
					d.say = "{them} braces and barely gives ground."
				"lock":
					d.gain = 0.8
					d.say = "{me} shoves straight through the body lock attempt!"
				"suplex":
					d.gain = 0.6 if not they_hold else 0.0
					d.say = "{me} drives in before the lift!" if not they_hold else ""
		"drag":
			match theirs:
				"push":
					d.gain = 1.0
					d.unbalances = true
					d.say = "Arm drag! {me} pulls the push past and {them} stumbles toward the edge."
				"brace":
					d.gain = 0.4
					d.unbalances = true
					d.say = "{me} drags the arm and gets an angle: {them} is off balance."
				"suplex":
					d.breaks = true
					d.gain = 0.3 if they_hold else 0.0
					d.say = "{me} drags the arm free and breaks the lock." if they_hold else ""
		"lock":
			match theirs:
				"drag":
					d.gain = 0.6
					d.lock = true
					d.say = "{me} steps in past the arm drag and locks his hands round {them}!"
				"brace":
					d.gain = 0.2
					d.lock = true
					d.say = "Body lock! {me} has his hands locked round {them}."
				"lock":
					d.say = "Both reach for the body lock: a tangle of arms."
				"suplex":
					d.gain = 0.0
		"suplex":
			if i_hold:
				match theirs:
					"brace":
						d.gain = 0.9
						d.say = "Suplex! {them} braces but is hoisted and slammed toward the edge."
					"drag":
						d.say = ""
					_:
						d.gain = 2.0
						d.say = "SUPLEX! {me} lifts {them} clean off the deck and throws him toward the side!"
			else:
				d.self_off = true
				d.say = "{me} tries to lift with no hold and staggers off balance."
		"brace":
			match theirs:
				"suplex":
					d.say = ""
				"brace":
					d.say = "Both brace and circle."
	return d


## Has the bout been won? Edges at +/- `edge` m from the centreline.
static func winner(bout: Dictionary, edge: float) -> int:
	if bout.pos >= edge - GAP:
		return bout.a # b driven off the starboard side
	if bout.pos <= -edge + GAP:
		return bout.b
	return 0
