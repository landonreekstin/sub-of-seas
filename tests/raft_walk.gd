extends SceneTree
## Rafts to the beaches (Blaney): out on deck, a raft out of the locker, climb in, fit the rocket,
## flat out to an island (250 mph, skipping), up the beach, out and walk the sand, back in the
## raft, back alongside the boat, into the sea, tread water on the waves (Space), and the empty
## raft is stowed.
##   godot --headless --path . -s tests/raft_walk.gd -- <sub>

var _game: Node
var _step := 0
var _t := 0.0
var _bad: Array[String] = []
var _D: GDScript
var _A: GDScript
var _raft: Variant
var _top := 0.0
var _mark := Vector3.ZERO
var _low := INF


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var net: Node = root.get_node("Net")
	var sub: String = args[0] if not args.is_empty() else "gato"
	net.mission = "cw_convoy" if sub == "typhoon" else "convoy"
	net.sub_key = sub
	net.debug_depth = 0.0
	net.mode = 1
	net.port = int(OS.get_environment("TEST_PORT")) if OS.has_environment("TEST_PORT") else 7100 + OS.get_process_id() % 2000
	Engine.time_scale = 2.0
	change_scene_to_file.call_deferred("res://game/game.tscn")


func _fail(why: String) -> void:
	_bad.append(why)
	print("  FAIL: ", why)


func _next() -> void:
	_step += 1
	_t = 0.0


func _physics_process(delta: float) -> bool:
	if _game == null:
		if current_scene != null and current_scene.name == "Game":
			_game = current_scene
		return false
	var me: Variant = _game.local_player
	var deck: Variant = _game.get("deck")
	var away: Variant = _game.get("away")
	var world: Variant = root.get_node("Sim").get("world")
	if me == null or deck == null or away == null or world == null:
		return false
	if _D == null:
		_D = load("res://game/deck.gd")
		_A = load("res://game/away.gd")
	_t += delta
	var sub: Variant = world.sub
	var o: Vector3 = _D.ORIGIN
	if _t > 90.0:
		_fail("stuck at step %d" % _step)
		_step = 99
	match _step:
		0:
			if _t < 1.0:
				return false
			sub.telegraph = 0
			sub.speed = 0.0
			me.go_on_deck()
			_next()
		1: # the locker
			if _t < 1.0:
				return false
			var locker: Node = null
			for n: Node in deck.get_children():
				if n.has_method("get_prompt") and "life raft" in str(n.get_prompt(me)):
					locker = n
			if locker == null:
				_fail("no raft locker on deck")
				_step = 99
				return false
			locker.interact(me)
			_next()
		2: # a raft alongside to starboard: climb down into her
			if _t < 0.5:
				return false
			if world.rafts.size() != 1:
				_fail("the locker put %d rafts over" % world.rafts.size())
				_step = 99
				return false
			_raft = world.rafts[0]
			me.global_position = o + Vector3(float(deck.dims.beam) * 0.5 - 0.6, float(deck.dims.deck) + 0.2, 0.0)
			if away.prompt_for(me) == "":
				_fail("standing at her side by the raft, no prompt to climb in (raft %.1f m off)" % _raft.pos.distance_to(sub.pos))
			away.interact(me)
			_next()
		3: # seated, driving; the boat can't dive now
			if _t < 0.5:
				return false
			if _raft.seat_of(me.peer_id) != 0 or not _A.is_rafting(me.global_position):
				_fail("not seated as driver (seat %d, at %s)" % [_raft.seat_of(me.peer_id), str(me.global_position)])
			if _game.exterior.eye_mode != "world":
				_fail("the view isn't from the raft (%s)" % _game.exterior.eye_mode)
			if not _game.crew_on_deck():
				_fail("with a man in a raft the boat would dive")
			_game.rq_raft_rocket(_raft.id)
			# Off 900 m from the nearest island's beach, bow on to it.
			var island: int = _A.nearest_island(world.seabed, _raft.pos)
			var f: Dictionary = world.seabed.features[island]
			var c := Vector2(f.x, f.y)
			var out: Vector2 = (_raft.pos - c).normalized()
			var p := c
			while world.seabed.floor_depth(p) < 0.0:
				p += out * 5.0
			_raft.pos = p + out * 900.0
			_raft.heading = fposmod(rad_to_deg(atan2(-out.x, -out.y)), 360.0)
			_next()
		4: # flat out for the beach
			if not _raft.rocket:
				if _t > 1.0:
					_fail("the rocket wasn't fitted")
					_step = 99
				return false
			Input.action_press("move_forward")
			_top = maxf(_top, _raft.speed)
			if _raft.bumps > 0 and _t > 2.0:
				Input.action_release("move_forward")
				_next()
		5: # skid to a stop on the sand
			if not _raft.beached() and _t < 12.0:
				return false
			print("  top speed %d mph, %d skips, %d bumps" % [roundi(_top * 2.237), _raft.skips, _raft.bumps])
			if _top * 2.237 < 230.0:
				_fail("she only made %d mph" % roundi(_top * 2.237))
			if _raft.skips < 1:
				_fail("she never skipped")
			if not _raft.beached():
				_fail("she didn't end up on the beach (ground %.1f, speed %.1f)" % [_raft.ground, _raft.speed])
			away.get_out(_raft)
			_next()
		6: # ashore
			if _t < 1.0:
				return false
			if not _A.is_ashore(me.global_position) or not _game.crew.get("ashore", {}).has(me.peer_id):
				_fail("getting out on the beach didn't put him ashore")
				_step = 99
				return false
			if _raft.seat_of(me.peer_id) >= 0:
				_fail("still in a seat after getting out")
			if not me.is_on_floor():
				_fail("not standing on the sand: %s" % str(me.global_position - _A.ASHORE))
			# Up the beach, toward the island's middle.
			var island: int = _game.crew.ashore[me.peer_id]
			var dir: Vector3 = _game.exterior.to_3d(_A.island_centre(island)) - _game.exterior.to_3d(_raft.pos)
			me.rotation.y = atan2(-dir.x, -dir.z)
			_mark = me.global_position
			Input.action_press("move_forward")
			_next()
		7:
			if _t < 4.0:
				return false
			Input.action_release("move_forward")
			var walked: float = Vector2(me.global_position.x - _mark.x, me.global_position.z - _mark.z).length()
			var y: float = me.global_position.y - _A.ASHORE.y
			print("  walked %.1f m up the beach, %.1f m above the sea" % [walked, y])
			if walked < 4.0:
				_fail("he couldn't walk up the beach (%.1f m)" % walked)
			if y < 0.0 or not me.is_on_floor():
				_fail("not on the ground after walking (%.1f m, floor %s)" % [y, me.is_on_floor()])
			# Back down to the raft.
			var island: int = _game.crew.ashore[me.peer_id]
			var at: Vector3 = _game.exterior.to_3d(_raft.pos) - _game.exterior.to_3d(_A.island_centre(island))
			me.global_position = _A.ASHORE + at + Vector3(1.5, maxf(_raft.ground, 0.0) + 1.0, 0.0)
			_next()
		8:
			if _t < 1.0:
				return false
			if away.prompt_for(me) != "[E] Get in the raft":
				_fail("by the beached raft, no prompt to get in (%s)" % away.prompt_for(me))
			away.interact(me)
			_next()
		9: # in again; tow her alongside the boat and get out into the sea
			if _t < 0.5:
				return false
			if _raft.seat_of(me.peer_id) < 0:
				_fail("he couldn't get back in the raft")
				_step = 99
				return false
			if _game.crew.get("ashore", {}).has(me.peer_id):
				_fail("still marked ashore, in the raft")
			_raft.rocket = false
			_raft.ground = -1.0
			_raft.speed = 0.0
			var h := deg_to_rad(sub.heading)
			_raft.pos = sub.pos + Vector2(cos(h), -sin(h)) * (float(deck.dims.beam) * 0.5 + 4.0)
			_next()
		10:
			if _t < 0.5:
				return false
			away.get_out(_raft)
			_next()
		11: # in the sea by her: Space treads water, the head over the waves
			if _t < 1.0:
				return false
			if not _D.is_out(me.global_position) or not _D.is_swimming(me.global_position):
				_fail("out of the raft by the boat, he isn't swimming beside her: %s" % str(me.global_position - o))
			Input.action_press("jump")
			_next()
		12:
			if _t > 1.0:
				var eye: float = me.global_position.y + me.EYE_HEIGHT
				var sea: float = o.y + _D.wave_at(me.global_position)
				_low = minf(_low, eye - sea)
			if _t < 5.0:
				return false
			Input.action_release("jump")
			print("  treading water: the eye at least %.2f m over the waves" % _low)
			if _low < 0.05:
				_fail("treading water, his eye went under the waves (%.2f)" % _low)
			_next()
		13: # the empty raft is stowed
			if world.rafts.is_empty():
				_step = 99
			elif _t > 22.0:
				_fail("the empty raft alongside was never stowed")
				_step = 99
		99:
			Input.action_release("move_forward")
			Input.action_release("jump")
			print("raft walk: %s" % ("ok" if _bad.is_empty() else str(_bad)))
			quit(1 if not _bad.is_empty() else 0)
			return true
	return false
