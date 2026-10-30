class_name BotCrew
extends Node
## Bot crewmen (lando: optional AI crew to fill out a small crew). Any crewman posts one to an
## empty station (B) and stands it down again (B at the bot). A bot either follows its orders
## (set from the orders panel: E at the bot) or acts on its own ("auto"). The host runs them,
## through the same order path as the players, so everything they do replicates as usual.
## Bots live in crew state: crew.bots[station_id] = {id, name, auto, course, speed, depth, ...}
## and they occupy their station (crew.stations) under a negative id.

const NAMES := ["Cookie", "Sparks", "Stubby", "Doc", "Mac", "Swede", "Tex", "Lucky", "Moose", "Red", "Chips", "Gunner"]
const TICK := 0.5

var game: Game
var _timer := 0.0
var _last_fire := -INF
var _hunted_until := -INF


## What a bot at this station is called in its job.
static func job(station_id: String) -> String:
	if station_id.begins_with("tube_"):
		return "torpedoman"
	return {"helm": "helmsman", "dive": "planesman", "ballast": "ballast man", "periscope": "lookout",
		"tdc": "TDC operator", "sonar": "sonarman", "engine": "motor machinist", "air": "auxiliaryman",
		"nav": "navigator", "darts": "darts player"}.get(station_id, "crewman")


# --- Requests (host) -------------------------------------------------------------

func request(station_id: String, key: String, value: Variant) -> void:
	var bots: Dictionary = game.crew.get_or_add("bots", {})
	match key:
		"post":
			if bots.has(station_id) or game.station_occupant(station_id) != 0 or not game.interior.stations.has(station_id):
				return
			var id := int(game.crew.get("next_bot", -1))
			game.crew.next_bot = id - 1
			var sub := Sim.world.sub
			var b := {"id": id, "name": NAMES[(-id - 1) % NAMES.size()], "auto": true,
				"course": sub.heading, "speed": sub.telegraph, "depth": sub.ordered_depth, "fire": false, "t": 0.0,
				"look": {"build": randi() % 4, "skin": randi() % 6, "hair": randi() % 7, "hair_col": randi() % 7,
					"beard": randi() % 7, "extra": randi() % 6, "hat": "watch", "hue": Profile.SHIRTS[randi() % Profile.SHIRTS.size()]}}
			bots[station_id] = b
			game.crew.stations[station_id] = id
			game.announce.rpc("%s takes the %s." % [b.name, game.interior.stations[station_id].display_name.to_lower()])
		"dismiss":
			if not bots.has(station_id):
				return
			var b: Dictionary = bots[station_id]
			game.crew.stations.erase(station_id)
			bots.erase(station_id)
			game.announce.rpc("%s stands down." % b.name)
		_:
			if not bots.has(station_id):
				return
			var b: Dictionary = bots[station_id]
			var sub := Sim.world.sub
			match key:
				"auto":
					b.auto = not b.auto
					if not b.auto: # orders start from how things are now
						b.course = sub.heading
						b.speed = sub.telegraph
						b.depth = sub.ordered_depth
				"course":
					b.course = fposmod(float(b.course) + float(value), 360.0)
				"speed":
					b.speed = clampi(int(b.speed) + int(value), -2, 4)
				"depth":
					b.depth = clampf(float(b.depth) + float(value), 0.0, sub.data.test_depth)
				"depth_to":
					b.depth = clampf(float(value), 0.0, sub.data.test_depth)
				"fire", "mark", "report", "vent", "blow":
					b[key] = true
	game.push_crew()


# --- Brains (host) ------------------------------------------------------------

func _process(delta: float) -> void:
	if not multiplayer.is_server() or Sim.world == null or game.crew.get("result", "") != "":
		return
	_timer += delta
	if _timer < TICK:
		return
	_timer = 0.0
	var bots: Dictionary = game.crew.get("bots", {})
	if bots.is_empty():
		return
	var w := Sim.world
	if not w.charges.is_empty() or w.ships.any(func(s: ShipState) -> bool:
			return not s.is_sinking() and s.mode >= ShipAI.Mode.HUNT and s.pos.distance_to(w.sub.pos) < 6000.0):
		_hunted_until = w.time + 30.0
	var hunted := w.time < _hunted_until
	for sid: String in bots.keys():
		if w.hull.is_broken(sid):
			continue
		var b: Dictionary = bots[sid]
		b.t = float(b.t) + TICK
		if sid.begins_with("tube_"):
			_torpedoman(sid, b)
		elif has_method("_" + sid):
			call("_" + sid, b, hunted)


func _order(sid: String, b: Dictionary, key: String, value: Variant = null) -> void:
	game.apply_order(sid, key, value, int(b.id))


## Holds the ordered course and speed; on auto, turns away and slows to a crawl when hunted.
func _helm(b: Dictionary, hunted: bool) -> void:
	var sub := Sim.world.sub
	var course := float(b.course)
	var speed := int(b.speed)
	if b.auto and hunted:
		var hunter := _nearest_hunter()
		if hunter != null:
			course = fposmod(ShipState.bearing(hunter.pos, sub.pos), 360.0) # run directly away
		speed = 1
	var err := wrapf(course - sub.heading, -180.0, 180.0)
	var rudder := 0 if absf(err) < 2.0 else clampi(roundi(err / 8.0), -3, 3)
	if rudder != sub.rudder:
		_order("helm", b, "rudder", rudder)
	if speed != sub.telegraph:
		_order("helm", b, "telegraph", speed)


## Holds the ordered depth; on auto, periscope depth, and deep (under the layer) when hunted.
func _dive(b: Dictionary, hunted: bool) -> void:
	var sub := Sim.world.sub
	var depth := float(b.depth)
	if b.auto:
		depth = sub.data.periscope_depth
		if hunted:
			var layer := Sim.world.conditions.layer_depth
			depth = layer + 15.0 if layer > 0.0 else 60.0
		depth = minf(depth, sub.data.test_depth - 10.0)
	var floor_at := Sim.world.seabed.floor_depth(sub.pos)
	depth = minf(depth, maxf(floor_at - 12.0, 0.0)) # never onto the bottom
	if absf(depth - sub.ordered_depth) > 0.5:
		_order("dive", b, "depth", depth)


## Floods the tanks to dive and blows them to surface, as the ordered depth needs.
func _ballast(b: Dictionary, _hunted: bool) -> void:
	var sub := Sim.world.sub
	if b.get("vent", false) or (b.auto and sub.ordered_depth > SubState.AWASH_DEPTH and sub.ballast < 0.99 and not sub.vents_open):
		b.vent = false
		_order("ballast", b, "vent")
	elif b.get("blow", false) or (b.auto and sub.ordered_depth <= 0.5 and sub.ballast > 0.0 and sub.blowing == 0 and not sub.is_surfaced()):
		b.blow = false
		if sub.vents_open:
			_order("ballast", b, "shut")
		_order("ballast", b, "blow")


## Calls out the loudest contact every 20 s (or when asked) and puts it on the chart.
func _sonar(b: Dictionary, _hunted: bool) -> void:
	if not (b.get("report", false) or (b.auto and float(b.t) >= 20.0)):
		return
	b.report = false
	b.t = 0.0
	var heard := SonarStation.contacts(Sim.world.sub)
	if heard.is_empty():
		return
	heard.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.loud > y.loud)
	var top: Dictionary = heard[0]
	var what: String = "biological, a whale" if top.c is Whale else SonarStation.classify(top.c).get_slice(" — ", 1).to_lower()
	game.announce.rpc("%s (sonar): contact bearing %03d, %s." % [b.name, roundi(top.b) % 360, what])
	_order("sonar", b, "plot", float(top.b))


## Raises the scope at periscope depth, marks the nearest ship every 25 s, ducks when hunted.
func _periscope(b: Dictionary, hunted: bool) -> void:
	var sub := Sim.world.sub
	var can := sub.depth <= sub.data.periscope_depth + 1.0
	if not b.auto and not b.get("mark", false):
		return
	if hunted or not can:
		if sub.periscope_raised:
			_order("periscope", b, "raised", false)
		return
	if not sub.periscope_raised:
		_order("periscope", b, "raised", true)
		return
	if not (b.get("mark", false) or float(b.t) >= 25.0):
		return
	b.mark = false
	b.t = 0.0
	var best: ShipState = null
	for s in Sim.world.ships:
		if not s.is_sinking() and s.pos.distance_to(sub.pos) < 8000.0 and (best == null or s.pos.distance_to(sub.pos) < best.pos.distance_to(sub.pos)):
			best = s
	if best != null:
		var r := best.pos.distance_to(sub.pos) * randf_range(0.97, 1.03)
		_order("periscope", b, "mark", [best.id, ShipState.bearing(sub.pos, best.pos), r])


## Sends the solution to the tubes once it has two marks.
func _tdc(b: Dictionary, _hunted: bool) -> void:
	var tdc: Dictionary = game.crew.tdc
	if b.auto and tdc.marks.size() >= 2 and not tdc.follow:
		_order("tdc", b, "send")


## Keeps the tube loaded, flooded and (with a solution) the door open; fires on the order, or
## on auto when the solution is good and the target close (one fish every 4 s across tubes).
func _torpedoman(sid: String, b: Dictionary) -> void:
	var t: Dictionary = game.crew.tubes[sid.trim_prefix("tube_").to_int() - 1]
	if not t.loaded:
		if t.reload == 0.0 and not t.flooded and not t.door and game.crew.reserve > 0:
			_order(sid, b, "load")
		elif t.door:
			_order(sid, b, "door")
		elif t.flooded:
			_order(sid, b, "flood")
		return
	var sol := game.tdc_solution(t.get("stern", false))
	var want_door: bool = b.get("fire", false) or (game.crew.tdc.follow and sol.ok)
	if not t.flooded and (want_door or b.auto):
		_order(sid, b, "flood")
	elif t.flooded and want_door and not t.door:
		_order(sid, b, "door")
	elif t.door and Sim.world.time - _last_fire > 4.0:
		var good: bool = sol.ok and float(sol.get("quality", 0.0)) > 0.7 and float(sol.get("range", 9e9)) < 3000.0
		if b.get("fire", false) or (b.auto and good):
			b.fire = false
			_last_fire = Sim.world.time
			_order(sid, b, "fire")


## Runs the diesels on the surface to charge, stops them before a dive.
func _engine(b: Dictionary, _hunted: bool) -> void:
	if not b.auto:
		return
	var sub := Sim.world.sub
	var diving := sub.ordered_depth > 0.5 or sub.vents_open
	for i in sub.diesels.size():
		if diving and sub.diesels[i] > 0.0:
			_order("engine", b, "diesel", [i, false])
		elif not diving and sub.is_surfaced() and sub.diesels[i] == 0.0 and sub.battery < 0.98:
			_order("engine", b, "diesel", [i, true])


## Changes the CO2 canister and works the oxygen bleed to keep the air sweet.
func _air(b: Dictionary, _hunted: bool) -> void:
	if not b.auto:
		return
	var air := Sim.world.air
	if air.canister_left <= 0.0 and air.co2 > 1.5 and air.canisters > 0:
		_order("air", b, "canister")
	if air.o2 < 18.5 and not air.bleed:
		_order("air", b, "bleed", true)
	elif air.o2 > 20.0 and air.bleed:
		_order("air", b, "bleed", false)


## Watches the chart ahead and sings out about shoal water.
func _nav(b: Dictionary, _hunted: bool) -> void:
	if not b.auto or float(b.t) < 15.0:
		return
	var sub := Sim.world.sub
	var dir := sub.direction()
	for d in [300.0, 600.0, 1000.0, 1500.0]:
		var depth := Sim.world.seabed.floor_depth(sub.pos + dir * d)
		if depth < maxf(sub.depth, SubState.AWASH_DEPTH) + 10.0:
			b.t = 0.0
			game.announce.rpc("%s (navigator): %s %d metres ahead!" % [b.name, "LAND" if depth < 0.0 else "shoal water", roundi(d)])
			return


## Plays darts between watches.
func _darts(b: Dictionary, _hunted: bool) -> void:
	if float(b.t) >= 45.0:
		b.t = 0.0
		_order("darts", b, "score", randi_range(15, 140))


func _nearest_hunter() -> ShipState:
	var sub := Sim.world.sub
	var best: ShipState = null
	for s in Sim.world.ships:
		if not s.is_sinking() and s.mode >= ShipAI.Mode.HUNT and (best == null or s.pos.distance_to(sub.pos) < best.pos.distance_to(sub.pos)):
			best = s
	return best
