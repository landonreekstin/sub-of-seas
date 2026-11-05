class_name BotCrew
extends Node
## Bot crewmen (lando: optional AI crew to fill out a small crew). Any crewman posts one to an
## empty station (B) and stands it down again (B at the bot). A bot either follows its orders
## (set from the orders panel: E at the bot) or acts on its own ("auto"). The host runs them,
## through the same order path as the players, so everything they do replicates as usual.
## Bots live in crew state: crew.bots[station_id] = {id, name, auto, course, speed, depth, ...}
## and they occupy their station (crew.stations) under a negative id.

const NAMES_SOVIET := ["Ivanov", "Petrov", "Sidorov", "Volkov", "Kuznetsov", "Sokolov", "Popov", "Lebedev", "Orlov", "Morozov", "Vasiliev", "Borodin"]
const NAMES := ["Cookie", "Sparks", "Stubby", "Doc", "Mac", "Swede", "Tex", "Lucky", "Moose", "Red", "Chips", "Gunner"]
const TICK := 0.5
const FULL_CREW := {"s_boat": 42, "gato": 80, "narwhal": 88, "typhoon": 160} ## a full complement, for "all hands"

var game: Game
var _timer := 0.0
var _last_fire := -INF
var _hunted_until := -INF
var _quiet := false ## posting for a PA order: the reply speaks for them
var plan := {} ## what the crew are carrying out for the skipper: {kind: "attack", id, ...}


## What a bot at this station is called in its job.
static func job(station_id: String) -> String:
	if station_id.begins_with("tube_"):
		return "torpedoman"
	return {"helm": "helmsman", "dive": "planesman", "ballast": "ballast man", "periscope": "lookout",
		"tdc": "TDC operator", "sonar": "sonarman", "engine": "motor machinist", "air": "auxiliaryman", "bilge": "pump man", "gun": "gunlayer", "ammo": "ammunition passer",
		"nav": "navigator", "darts": "darts player", "first_mate": "first mate", "skipper": "skipper's writer", "holo": "officer of the watch"}.get(station_id, "crewman")


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
			var b := {"id": id, "name": (NAMES_SOVIET if sub.data.nuclear else NAMES)[(-id - 1) % NAMES.size()], "auto": true,
				"course": sub.heading, "speed": sub.telegraph, "depth": sub.ordered_depth, "fire": false, "t": 0.0,
				"look": {"build": randi() % 4, "skin": randi() % 6, "hair": randi() % 7, "hair_col": randi() % 7,
					"beard": randi() % 7, "extra": randi() % 6, "hat": "watch", "hue": Profile.SHIRTS[randi() % Profile.SHIRTS.size()]}}
			bots[station_id] = b
			game.crew.stations[station_id] = id
			if not _quiet:
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
				"fire" when station_id == "gun": # open fire / cease fire
					b.fire = not b.get("fire", false)
				"pass": # pass ammunition up / hold it
					b.pass = not b.get("pass", true)
				"fire", "mark", "report", "vent", "blow":
					b[key] = true
				"pump":
					b.pump = bool(value)
	game.push_crew()


# --- Brains (host) ------------------------------------------------------------

func _process(delta: float) -> void:
	if not multiplayer.is_server() or Sim.world == null or game.crew.get("result", "") != "":
		return
	_timer += delta
	if _timer < TICK:
		return
	_timer = 0.0
	_step_news()
	_step_party()
	var bots: Dictionary = game.crew.get("bots", {})
	if bots.is_empty():
		return
	var w := Sim.world
	if not w.charges.is_empty() or w.ships.any(func(s: ShipState) -> bool:
			return not s.is_sinking() and s.mode >= ShipAI.Mode.HUNT and s.pos.distance_to(w.sub.pos) < 6000.0):
		_hunted_until = w.time + 30.0
	var hunted := w.time < _hunted_until
	_step_plan()
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
	var rudder := 0 if absf(err) < 1.5 else clampi(int(signf(err)) * maxi(1, roundi(absf(err) / 8.0)), -3, 3)
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
	if b.get("emergency", false):
		b.emergency = false
		_order("ballast", b, "emergency")
	elif b.get("vent", false) or (b.auto and sub.ordered_depth > SubState.AWASH_DEPTH and sub.ballast < 0.99 and not sub.vents_open):
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
	if top.c is ShipState and top.c.data.role == "sub":
		game.alarm.rpc() # the one sonar report worth waking people for
	game.announce.rpc("%s (sonar): contact bearing %03d, %s." % [b.name, roundi(top.b) % 360, what])
	_order("sonar", b, "plot", float(top.b))


## Raises the scope at periscope depth, marks the nearest ship every 25 s, ducks when hunted.
func _periscope(b: Dictionary, hunted: bool) -> void:
	var sub := Sim.world.sub
	var can := sub.depth <= sub.data.periscope_depth + 1.0
	if not b.auto and not b.get("mark", false):
		return
	if (hunted and plan.is_empty()) or not can:
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
	var best: ShipState = _plan_target()
	if best == null:
		for s in Sim.world.ships:
			if not s.is_sinking() and not s.submerged() and s.pos.distance_to(sub.pos) < 8000.0 and (best == null or s.pos.distance_to(sub.pos) < best.pos.distance_to(sub.pos)):
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
	var want_door: bool = b.get("fire", false) or b.get("ready", false) or (game.crew.tdc.follow and sol.ok)
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
	if not b.auto or Sim.world.sub.data.nuclear:
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


## Runs the bilge pump while there's water aboard, but stops it while the boat is hunted.
## On orders, he runs it or stops it as told.
func _bilge(b: Dictionary, hunted: bool) -> void:
	var hull := Sim.world.hull
	var wet := hull.comps.any(func(c: Dictionary) -> bool: return c.water > 0.02)
	var want: bool = (wet and not hunted) if b.auto else bool(b.get("pump", hull.bilge_on))
	if want != hull.bilge_on:
		_order("bilge", b, "pump", want)


## Lays the gun on the nearest ship in range and fires as fast as it's loaded, leading her by the
## shell's time of flight, his range a few percent out. On his own he engages whatever comes in
## range while she's on the surface; on orders, only after "open fire".
func _gun(b: Dictionary, _hunted: bool) -> void:
	var w := Sim.world
	var gun: Dictionary = game.crew.get("gun", {})
	if not w.sub.is_surfaced() or int(gun.get("ready", 0)) <= 0 or w.time < float(gun.get("next", 0.0)):
		return
	if not b.auto and not b.get("fire", false):
		return
	var target := _gun_target()
	if target == null:
		return
	var flight := target.pos.distance_to(w.sub.pos) / OceanWorld.SHELL_SPEED
	var aim := target.pos + target.direction() * target.speed * flight
	var r := w.sub.pos.distance_to(aim) * (1.0 + randf_range(-0.04, 0.04))
	_order("gun", b, "fire", [ShipState.bearing(w.sub.pos, aim) + randf_range(-0.3, 0.3), r])


## The nearest ship afloat within the gun's reach and arc.
func _gun_target() -> ShipState:
	var sub := Sim.world.sub
	var best: ShipState = null
	for s in Sim.world.ships:
		var d := s.pos.distance_to(sub.pos)
		var rel := wrapf(ShipState.bearing(sub.pos, s.pos) - sub.heading, -180.0, 180.0)
		if s.is_sinking() or s.passive or s.submerged() or d > sub.data.gun_range * 0.85 or absf(rel) > GunStation.ARC:
			continue
		if best == null or d < best.pos.distance_to(sub.pos):
			best = s
	return best


## Passes rounds up to the gun whenever there's room in its locker (unless told to hold).
func _ammo(b: Dictionary, _hunted: bool) -> void:
	if b.auto or b.get("pass", true):
		_order("ammo", b, "pass")


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


# --- The skipper's PA (host) -------------------------------------------------------

## A line from the PA: says it to the boat, and the crew reply and get on with it.
func skipper_order(text: String, who: String) -> void:
	var orders := CrewCommand.parse(text)
	game.pa_call.rpc(who, text)
	if orders.is_empty():
		game.announce.rpc("Crew: Say again, Skipper? We didn't follow that one.")
		return
	var replies: Array[String] = []
	_quiet = true
	for o: Dictionary in orders:
		replies.append(_carry_out(o))
	_quiet = false
	game.announce.rpc("Crew: " + " ".join(replies))
	if orders.any(func(o: Dictionary) -> bool: return o.intent in ["attack", "evade", "course", "depth", "speed", "enemy_sub"]):
		game.crew.orders = text
	game.push_crew()


## Does one order; returns what the crew say back.
func _carry_out(o: Dictionary) -> String:
	var sub := Sim.world.sub
	match o.intent:
		"depth":
			return _order_depth(o)
		"course":
			var course := _course_for(o)
			if is_nan(course):
				return "No land on the chart, Skipper."
			plan.clear()
			return _hand("helm", func(b: Dictionary) -> void:
				b.course = course
				if int(b.speed) == 0:
					b.speed = 2) + "Coming to %03d." % (roundi(course) % 360)
		"speed":
			var t: int = clampi(int(o.get("telegraph", sub.telegraph + int(o.get("change", 0)))), -2, 4)
			return _hand("helm", func(b: Dictionary) -> void: b.speed = t) + "%s." % SubState.TELEGRAPH_NAMES[t].capitalize()
		"attack":
			return _order_attack(o)
		"evade":
			return _order_evade()
		"cancel":
			plan.clear()
			game.crew.orders = ""
			var gun: Dictionary = game.crew.get("bots", {}).get("gun", {})
			gun.fire = false
			return "Belay that, aye."
		"man_stations":
			for sid: String in _watch_stations():
				if game.station_occupant(sid) == 0:
					request(sid, "post", null)
			if sub.data.key == "typhoon":
				game.crew.full_crew = true
				return "All hands, Skipper: 160 men at their posts, damage parties standing by."
			return "All stations manned, Skipper."
		"all_hands":
			return all_hands()
		"stand_down":
			plan.clear()
			game.crew.full_crew = false
			party_size = 0
			game.crew.orders = ""
			for sid: String in game.crew.get("bots", {}).keys():
				request(sid, "dismiss", null)
			return "Standing down."
		"fix":
			return call_damage_party()
		"reload":
			for t: Dictionary in game.crew.tubes:
				var sid := "tube_%d" % (game.crew.tubes.find(t) + 1)
				if not t.loaded and game.station_occupant(sid) == 0:
					request(sid, "post", null)
			return "Reloading the tubes."
		"gun":
			if not sub.is_surfaced() or not game.interior.stations.has("gun"):
				return "The gun's no use from here, Skipper." if sub.is_surfaced() else "Can't reach the gun dived, Skipper: surface first."
			return _hand("gun", func(b: Dictionary) -> void: b.fire = true) + _ammo_up() + "Opening fire."
		"air":
			if game.station_occupant("air") == 0:
				request("air", "post", null)
			return "Keeping the air sweet."
		"report":
			game.crew.mate_read = game.crew.get("mate_news", 0)
			var trouble := problems()
			return "All in order, Skipper." if trouble.is_empty() else "%s (%d more)" % [trouble[0], trouble.size() - 1] if trouble.size() > 1 else trouble[0]
		"contacts":
			return _contacts_report()
		"objective":
			return _objective_report()
		"enemy_sub":
			return game.call_enemy_sub(o.get("attack", false))
		"band":
			return game.call_band(o.get("off", false))
	return "Aye."


## Gets a bot on `sid` (posting one if it's free) and tells him what to do. A player holding it
## gets the skipper's word on his screen instead. Returns what to add to the reply.
func _hand(sid: String, what: Callable) -> String:
	if not game.interior.stations.has(sid):
		return ""
	if game.station_occupant(sid) > 0:
		game.notice.rpc_id(game.station_occupant(sid), "That order's for you on the %s." % game.interior.stations[sid].display_name.to_lower())
		return "%s has the %s. " % [game.crew_name(game.station_occupant(sid)), game.interior.stations[sid].display_name.to_lower()]
	if game.station_occupant(sid) == 0:
		request(sid, "post", null)
	var b: Dictionary = game.crew.bots.get(sid, {})
	if b.is_empty():
		return ""
	b.auto = false
	what.call(b)
	return ""


func _ammo_up() -> String:
	if game.station_occupant("ammo") == 0 and game.interior.stations.has("ammo"):
		request("ammo", "post", null)
	return ""


## Every working station a full watch would man (not the rec room's or the sightseeing ones).
func _watch_stations() -> Array[String]:
	var out: Array[String] = []
	for sid: String in game.interior.stations:
		if sid in ["darts", "sand_table", "cameras", "nav", "skipper", "holo"] or (sid in ["gun", "ammo"] and not Sim.world.sub.is_surfaced()):
			continue
		out.append(sid)
	return out


func _order_depth(o: Dictionary) -> String:
	var sub := Sim.world.sub
	var w := Sim.world
	var floor_at := w.seabed.floor_depth(sub.pos)
	var limit := sub.data.test_depth
	var to := 0.0
	var say := ""
	match o.get("to", ""):
		"surface":
			to = 0.0
			say = "Surfacing."
		"crash": # an emergency blow: from any depth she'll breach (SubState.breach)
			_hand("dive", func(b: Dictionary) -> void: b.depth = 0.0)
			if game.station_occupant("ballast") == 0:
				request("ballast", "post", null)
			var bb: Dictionary = game.crew.get("bots", {}).get("ballast", {})
			if not bb.is_empty():
				bb.emergency = true
			elif game.station_occupant("ballast") > 0:
				game.notice.rpc_id(game.station_occupant("ballast"), "Skipper: emergency blow! X twice on the ballast.")
			return "Emergency blow! Crash surface, hold on!"
		"periscope":
			to = sub.data.periscope_depth
			say = "Periscope depth."
		"dive":
			to = maxf(45.0, sub.data.periscope_depth + 15.0)
			say = "Diving to %d metres." % roundi(to)
		"deep":
			to = limit - 5.0
			say = "Taking her deep, %d metres." % roundi(to)
		"bottom":
			to = maxf(floor_at - 12.0, 0.0)
			say = "Down to the bottom, %d metres." % roundi(to)
			if to > limit - 5.0:
				to = limit - 5.0
				say = "The bottom's %d metres down and she'd crush. Going as deep as she'll take, %d." % [roundi(floor_at), roundi(to)]
		_:
			to = float(o.metres) if o.has("metres") else sub.ordered_depth + float(o.get("change", 0.0))
			to = clampf(to, 0.0, limit)
			say = "Making our depth %d metres." % roundi(to)
	if to > SubState.AWASH_DEPTH and game.crew_on_deck():
		return "Can't dive, Skipper: there's crew out on deck!"
	var reply := _hand("dive", func(b: Dictionary) -> void: b.depth = to)
	if game.interior.stations.has("ballast") and game.station_occupant("ballast") == 0:
		request("ballast", "post", null)
	if game.station_occupant("engine") == 0 and game.interior.stations.has("engine") and to > SubState.AWASH_DEPTH:
		request("engine", "post", null) # the diesels have to stop before she goes under
	return reply + say


func _course_for(o: Dictionary) -> float:
	var sub := Sim.world.sub
	if o.has("abs"):
		return float(o.abs)
	if o.get("island", false):
		var best := NAN
		var best_d := INF
		for f: Dictionary in Sim.world.seabed.features:
			var at := Vector2(f.x, f.y)
			if f.kind == "island" and at.distance_to(sub.pos) < best_d:
				best_d = at.distance_to(sub.pos)
				best = ShipState.bearing(sub.pos, at)
		return best
	return fposmod(sub.heading + float(o.get("rel", 0.0)), 360.0)


func _order_attack(o: Dictionary) -> String:
	var target := find_target(str(o.get("target", "")), o.get("dir", {}))
	if target == null:
		var what: String = str(o.get("target", "")) if o.get("target", "") != "" else "ship"
		return "No %s %s, Skipper." % [what, "that way" if not (o.get("dir", {}) as Dictionary).is_empty() else "in reach"]
	begin_attack(target)
	var far := target.pos.distance_to(Sim.world.sub.pos)
	return "%s, bearing %03d, %.1f km. Going after her." % [target.data.display_name, roundi(ShipState.bearing(Sim.world.sub.pos, target.pos)) % 360, far / 1000.0]


## Puts the crew on to `target`: helm, planes and the bow tubes, and the scope and TDC where the
## level uses them.
func begin_attack(target: ShipState) -> void:
	plan = {"kind": "attack", "id": target.id, "next": 0.0, "last": _last_fire, "fish": 0}
	var hands: Array[String] = ["helm", "dive", "ballast"]
	if not game.arcade_aim() and target.data.role != "sub":
		hands.append_array(["periscope", "tdc"] as Array[String])
	if target.data.role == "sub":
		hands.append("sonar")
	var tubes := 0
	for i in game.crew.tubes.size():
		if not game.crew.tubes[i].get("stern", false) and tubes < 3:
			hands.append("tube_%d" % (i + 1))
			tubes += 1
	for sid in hands:
		if game.station_occupant(sid) == 0 and game.interior.stations.has(sid):
			request(sid, "post", null)
	for sid: String in game.crew.get("bots", {}):
		if sid in ["helm", "dive"]:
			game.crew.bots[sid].auto = false


## The nearest ship of that kind in that direction that we could know about. Sound or sight
## reach about 15 km; a dived sub only counts as heard (SonarStation).
func find_target(kind: String, dir: Dictionary) -> ShipState:
	var w := Sim.world
	var sub := w.sub
	var best: ShipState = null
	for s in w.ships:
		var d := s.pos.distance_to(sub.pos)
		if s.is_sinking() or d > 15000.0 or not _matches(s, kind):
			continue
		if not dir.is_empty():
			var want: float = float(dir.abs) if dir.has("abs") else sub.heading + float(dir.rel)
			if absf(wrapf(ShipState.bearing(sub.pos, s.pos) - want, -180.0, 180.0)) > 60.0:
				continue
		if s.data.role == "sub" and not SonarStation.contacts(sub).any(func(c: Dictionary) -> bool: return c.c == s):
			continue
		if best == null or d < best.pos.distance_to(sub.pos):
			best = s
	return best


static func _matches(s: ShipState, kind: String) -> bool:
	match kind:
		"":
			return s.data.role != "sub"
		"merchant", "escort", "sub":
			return s.data.role == kind or (kind == "escort" and s.data.role == "chaser")
	return s.data.key == kind or s.data.kind == kind


func _plan_target() -> ShipState:
	if plan.get("kind", "") != "attack":
		return null
	for s in Sim.world.ships:
		if s.id == plan.id and not s.is_sinking():
			return s
	return null


## Steers the attack: the bow on to the lead, then a spread of three, then again until she goes.
func _step_plan() -> void:
	if plan.get("kind", "") == "objective":
		_work_objective()
		return
	if plan.get("kind", "") != "attack":
		return
	var target := _plan_target()
	var bots: Dictionary = game.crew.get("bots", {})
	var working: bool = plan.get("objective", false)
	if working and _survive_open() and Sim.world.time < _hunted_until: # hunted: lose them first
		target = null
	if target == null:
		plan.clear()
		for sid: String in bots:
			bots[sid].ready = false
			bots[sid].fire = false if sid.begins_with("tube_") else bots[sid].get("fire", false)
		if working:
			plan = {"kind": "objective"}
		else:
			game.crew.orders = ""
			game.announce.rpc("Crew: She's going down, Skipper. What next?")
		game.push_crew()
		return
	var w := Sim.world
	var sub := w.sub
	var r := target.pos.distance_to(sub.pos)
	var lead := w.lead_bearing(target)
	var course := ShipState.bearing(sub.pos, target.pos) if is_nan(lead) else lead
	if bots.has("helm"):
		bots.helm.course = course
		bots.helm.speed = 4 if r > 4000.0 else (3 if r > 2000.0 else 2)
	if bots.has("dive"):
		bots.dive.depth = target.depth if target.data.role == "sub" else sub.data.periscope_depth
	if not game.arcade_aim() and target.data.role != "sub": # a sub is hunted by ear: down the bearing at any level
		if bots.has("periscope"):
			bots.periscope.auto = true
			bots.periscope.mark = float(bots.periscope.t) >= 10.0
		return
	if _last_fire > float(plan.last):
		plan.last = _last_fire
		plan.fish = int(plan.fish) + 1
		if int(plan.fish) % 3 == 0:
			plan.next = w.time + 45.0
	var in_reach: bool = r < Torpedo.MAX_RANGE * 0.8
	var on_target: bool = in_reach and not is_nan(lead) and absf(wrapf(lead - sub.heading, -180.0, 180.0)) <= OceanWorld.ARCADE_AIM_TOLERANCE and w.time >= float(plan.next)
	for sid: String in bots:
		if sid.begins_with("tube_") and not game.crew.tubes[sid.trim_prefix("tube_").to_int() - 1].get("stern", false):
			bots[sid].auto = false
			bots[sid].ready = in_reach
			bots[sid].fire = on_target


## "All hands on deck" (Blaney): every post manned, the boat filled with men, damage parties
## standing by, and the crew carry out the patrol's objective by themselves until told otherwise.
func all_hands() -> String:
	for sid: String in _watch_stations():
		if game.station_occupant(sid) == 0:
			request(sid, "post", null)
	game.crew.full_crew = true
	party_size = maxi(party_size, 4)
	plan = {"kind": "objective"}
	game.crew.orders = "All hands: " + _objective_report().trim_prefix("Our orders: ")
	return "All hands, Skipper: %d men aboard, every post manned, damage parties standing by. We'll see to the orders." % FULL_CREW.get(Sim.world.sub.data.key, 80)


func _survive_open() -> bool:
	return game.crew.get("objectives", []).any(func(o: Dictionary) -> bool: return o.kind == "survive" and not o.get("done", false))


## The objective's next step: lose whoever's hunting us on a "survive" patrol, else close on and
## sink the nearest ship it wants (any ship on the open patrol), then the next.
func _work_objective() -> void:
	var w := Sim.world
	var sub := w.sub
	var objectives: Array = game.crew.get("objectives", [])
	if _survive_open() and w.time < _hunted_until:
		if not plan.get("evading", false):
			var reply := _order_evade()
			plan = {"kind": "objective", "evading": true}
			game.announce.rpc("Crew: They're on to us. " + reply)
		return
	var target: ShipState = null
	for main in [true, false]: # the main objectives first, then the bonus ones
		for o: Dictionary in objectives:
			if o.get("done", false) or o.kind == "survive" or o.get("bonus", false) == main:
				continue
			for s: ShipState in game._targets(o):
				if target == null or s.pos.distance_to(sub.pos) < target.pos.distance_to(sub.pos):
					target = s
		if target != null:
			break
	if target == null and objectives.is_empty():
		target = find_target("", {})
	if target == null:
		if plan.get("evading", false) or plan.get("closing", -1) != -1:
			plan = {"kind": "objective"}
		return
	var r := target.pos.distance_to(sub.pos)
	if r > Torpedo.MAX_RANGE * 2.0: # too far to shoot: close on her at full speed
		var bots: Dictionary = game.crew.get("bots", {})
		if bots.has("helm"):
			bots.helm.auto = false
			bots.helm.course = ShipState.bearing(sub.pos, target.pos)
			bots.helm.speed = 4
		if bots.has("dive"):
			bots.dive.auto = false
			bots.dive.depth = sub.data.periscope_depth
		if plan.get("closing", -1) != target.id:
			plan = {"kind": "objective", "closing": target.id}
			game.announce.rpc("Crew: %s bearing %03d, %.0f km. Closing at full speed." % [target.data.display_name, roundi(ShipState.bearing(sub.pos, target.pos)) % 360, r / 1000.0])
		return
	begin_attack(target)
	plan.objective = true
	game.announce.rpc("Crew: Going after the %s, bearing %03d, %.1f km." % [target.data.display_name.to_lower(), roundi(ShipState.bearing(sub.pos, target.pos)) % 360, r / 1000.0])


## Away from whoever's after us: deep under the layer, slow and quiet.
func _order_evade() -> String:
	var w := Sim.world
	var sub := w.sub
	plan.clear()
	var layer := w.conditions.layer_depth
	var to := minf(layer + 15.0 if layer > 0.0 else 60.0, sub.data.test_depth - 10.0)
	var hunter := _nearest_hunter()
	var course := sub.heading if hunter == null else ShipState.bearing(hunter.pos, sub.pos)
	var reply := _hand("helm", func(b: Dictionary) -> void:
		b.course = course
		b.speed = 1)
	reply += _hand("dive", func(b: Dictionary) -> void: b.depth = to)
	if game.station_occupant("ballast") == 0 and game.interior.stations.has("ballast"):
		request("ballast", "post", null)
	return reply + "Going deep and quiet, %d metres, coming to %03d." % [roundi(to), roundi(course) % 360]


## Everything wrong with the boat, the worst first (the first mate's notebook reads this too).
func problems() -> Array[String]:
	var out: Array[String] = []
	var hull := Sim.world.hull
	for f: Dictionary in hull.fires:
		out.append("Fire in the %s." % hull.comps[f.c].name)
	for l: Dictionary in hull.leaks:
		out.append("Leak in the %s." % hull.comps[l.c].name)
	for sid: String in hull.broken:
		var st: Station = game.interior.stations.get(sid)
		out.append("The %s is %s." % [st.display_name.to_lower() if st != null else sid, "wrecked" if hull.needs_parts.has(sid) else "broken"])
	for c: Dictionary in hull.comps:
		if float(c.water) > 0.1:
			out.append("%d%% flooded in the %s." % [roundi(float(c.water) * 100.0), c.name])
	var air := Sim.world.air
	if air.co2 > 3.0 or air.o2 < 18.0:
		out.append("The air is going foul.")
	var sub := Sim.world.sub
	if sub.battery < 0.2 and sub.data.battery_endurance_min > 0.0:
		out.append("Battery down to %d%%." % roundi(sub.battery * 100.0))
	return out


func _contacts_report() -> String:
	var heard := SonarStation.contacts(Sim.world.sub)
	if heard.is_empty():
		return "Sonar has nothing, Skipper."
	heard.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.loud > y.loud)
	var out: Array[String] = []
	for k in mini(3, heard.size()):
		var c: Dictionary = heard[k]
		out.append("%s bearing %03d" % ["whale" if c.c is Whale else SonarStation.classify(c.c).get_slice(" — ", 1).to_lower(), roundi(c.b) % 360])
	return "Sonar has " + ", ".join(out) + "."


func _objective_report() -> String:
	var open: Array[String] = []
	for o: Dictionary in game.crew.get("objectives", []):
		if not o.get("done", false):
			open.append(str(o.text))
	return "Our orders: " + ("; ".join(open) + "." if not open.is_empty() else "free hunting, Skipper.")


# --- The damage party (host) -------------------------------------------------------

const TEAM_WALK := 3.5 ## m/s along the boat
const TEAM_WORK := 0.7 ## how fast against a crewman at the job themselves

var party_size := 0 ## damage-control teams turned out, 0 = none


## Turns out the damage party; they stand down once the boat is sound.
func call_damage_party() -> String:
	if problems().is_empty():
		return "Nothing needs fixing, Skipper."
	party_size = maxi(party_size, 2)
	if game.station_occupant("bilge") == 0 and game.interior.stations.has("bilge") and Sim.world.hull.water_fraction() > 0.0:
		request("bilge", "post", null)
	return "Damage party's on it."


## Teams walk to the next job nobody else has and work it, slower than a crewman would, and
## replicate through the hull snapshot so everyone sees them.
func _step_party() -> void:
	var hull := Sim.world.hull
	while hull.teams.size() < party_size:
		hull.teams.append({"p": game.interior.spawn_points[0], "job": ""})
	if party_size == 0:
		hull.teams.clear()
		_team_ways.clear()
		return
	var taken := {}
	for t: Dictionary in hull.teams:
		if t.job != "":
			taken[t.job] = true
	var busy := false
	for n in hull.teams.size():
		var t: Dictionary = hull.teams[n]
		var job := _job_at(t.job)
		if job.is_empty():
			job = _next_job(taken)
			t.job = str(job.get("id", ""))
			if t.job != "":
				taken[t.job] = true
		if job.is_empty():
			continue
		busy = true
		var there: Vector3 = job.p
		there.y = game.interior.floor_at(there)
		if _walk_team(n, there):
			continue
		if hull.work(job.tool, job.target, TICK * TEAM_WORK):
			game.announce.rpc(job.done)
			t.job = ""
			game.push_crew()
	if not busy and not game.crew.get("full_crew", false):
		party_size = 0
		hull.teams.clear()
		_team_ways.clear()


var _team_ways := {} ## team's index -> {job, legs, shut}: the host's route; not sent to the crew


## One tick along the team's route through the doors. False once they're at the job.
func _walk_team(n: int, there: Vector3) -> bool:
	var t: Dictionary = Sim.world.hull.teams[n]
	var way: Dictionary = _team_ways.get(n, {})
	if way.get("job", "") != t.job:
		way = {"job": t.job, "legs": game.interior.route(t.p, there), "shut": way.get("shut", "")}
		_team_ways[n] = way
	var p: Vector3 = t.p
	var left := TEAM_WALK * TICK
	var legs: Array = way.legs
	while left > 0.0 and not legs.is_empty():
		var door: String = legs[0].door
		if door != "" and not game.crew.doors.get(door, true):
			game.rq_door(door) # open up, and they'll shut it behind them
			way.shut = door
		var to: Vector3 = legs[0].p
		var d := p.distance_to(to)
		p = p.move_toward(to, left)
		left -= d
		if left >= 0.0:
			legs.pop_front()
	t.p = p
	if way.shut != "" and p.distance_to(game.interior.doors[way.shut].global_position) > 1.6:
		if game.crew.doors.get(way.shut, false):
			game.rq_door(way.shut)
		way.shut = ""
	if not legs.is_empty():
		return true
	if p.distance_to(there) > 1.4:
		t.p = p.move_toward(there, TEAM_WALK * TICK)
		return true
	return false


# --- The notebooks (Typhoon) --------------------------------------------------------

var _known_problems := 0


## New trouble is news: the skipper's notebook says to check in with the first mate. On the
## full crew's boat the damage parties stay turned out, the first mate sends them when a bot has
## his notebook, and a player with it sends them himself ([F]).
func _step_news() -> void:
	var n := problems().size()
	if n > _known_problems:
		game.crew.mate_news = int(game.crew.get("mate_news", 0)) + 1
		game.push_crew()
		var writer := game.station_occupant("skipper")
		if writer > 0:
			game.notice.rpc_id(writer, "Check in with the first mate: he has news.")
	_known_problems = n


## The first mate, a bot: sends the damage parties to whatever's on his list, and reads it out.
func _first_mate(b: Dictionary, _hunted: bool) -> void:
	var list := problems()
	if list.is_empty():
		b.news = 0
		return
	send_party()
	if list.size() > int(b.get("news", 0)):
		game.announce.rpc("%s (first mate): %s Damage party's going." % [b.name, list[0]])
	b.news = list.size()


## Sends the damage parties: four on a full crew, two otherwise.
func send_party() -> void:
	party_size = maxi(party_size, 4 if game.crew.get("full_crew", false) else 2)


## What the skipper should be thinking about, the most pressing first (his notebook).
func pressing() -> Array[String]:
	var out: Array[String] = []
	var w := Sim.world
	var sub := w.sub
	var fish := w.torpedoes.filter(func(t: Torpedo) -> bool: return t.enemy)
	if not fish.is_empty():
		out.append("TORPEDO IN THE WATER: turn away and go deep. Tell the PA \"get us out of here\".")
	if sub.reactor_down:
		out.append("Reactor tripped: emergency motors only until it's repaired.")
	if w.ships.any(func(s: ShipState) -> bool: return not s.is_sinking() and s.mode >= ShipAI.Mode.HUNT and s.pos.distance_to(sub.pos) < 6000.0):
		out.append("We're being hunted: go deep and quiet, or sink them.")
	if w.hull.water_fraction() > 0.08:
		out.append("Flooding, %d%% of the boat." % roundi(w.hull.water_fraction() * 100.0))
	if sub.depth > sub.data.test_depth * 0.9:
		out.append("Near test depth, %d m: she won't take much more." % roundi(sub.depth))
	var empty: Array[String] = []
	for sid in ["helm", "dive", "sonar"]:
		if game.station_occupant(sid) == 0:
			empty.append(game.interior.stations[sid].display_name.to_lower())
	if not empty.is_empty():
		out.append("Nobody on the %s. Say \"all hands\" on the PA." % ", the ".join(empty))
	if game.crew.get("orders", "") != "":
		out.append("Your last order is under way: %s" % game.crew.orders)
	for o: Dictionary in game.crew.get("objectives", []):
		if not o.get("done", false):
			out.append("Orders from the fleet: %s." % o.text)
	return out


## Live jobs by id, "" when it's done: {id, tool, target, p, done}.
func _job_at(id: String) -> Dictionary:
	if id == "":
		return {}
	for j: Dictionary in _jobs():
		if j.id == id:
			return j
	return {}


func _next_job(taken: Dictionary) -> Dictionary:
	for j: Dictionary in _jobs():
		if not taken.has(j.id):
			return j
	return {}


func _jobs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var hull := Sim.world.hull
	for f: Dictionary in hull.fires:
		out.append({"id": "f%d" % f.id, "tool": "extinguisher", "target": str(f.id), "p": f.p, "done": "Damage party: fire's out in the %s." % hull.comps[f.c].name})
	for l: Dictionary in hull.leaks:
		out.append({"id": "l%d" % l.id, "tool": "torch", "target": str(l.id), "p": l.p, "done": "Damage party: leak welded in the %s." % hull.comps[l.c].name})
	for sid: String in hull.broken:
		var st: Station = game.interior.stations.get(sid)
		if st == null:
			continue
		var wrecked := hull.needs_parts.has(sid)
		out.append({"id": "b%s" % sid, "tool": "parts" if wrecked else "wrench", "target": sid, "p": st.global_position,
			"done": "Damage party: %s the %s." % ["spare parts fitted to" if wrecked else "repaired", st.display_name.to_lower()]})
	return out
