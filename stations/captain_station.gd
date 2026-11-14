class_name CaptainStation
extends Station
## The captain's chair, in every boat (Blaney: "pilot the sub entirely alone by issuing
## commands"). Its keys are orders, not controls: the host hands each one to whoever has that
## post, a bot unless a player is on it (BotCrew.captain), so nobody is overridden; a player on
## the post sees what the captain wants and which key does it (hint_for, on his HUD). The panel
## shows everything needed to pilot her. H puts the navigation room's hologram on his screen.
## Built facing -Z; `look` is where his eye rests.

const PRESETS := ["surface", "periscope", "dive", "deep"] ## 1-4

var look := Vector3(0, 1.2, -2.0)
var _lines: Array[Label] = []
var _holo_view: Control ## the hologram full on his screen, while H has it up
var _confirm_until := 0.0


func _ready() -> void:
	Build.cyl(self, 0.08, 0.5, Vector3(0, 0.25, 0), Color("#1E1E1E"))
	Build.box(self, Vector3(0.55, 0.1, 0.55), Vector3(0, 0.55, 0), Color("#5A3A2E"))
	Build.box(self, Vector3(0.55, 0.7, 0.1), Vector3(0, 0.95, 0.27), Color("#5A3A2E"))
	for side in [-1.0, 1.0]:
		Build.box(self, Vector3(0.08, 0.08, 0.45), Vector3(side * 0.28, 0.78, 0), Color("#1E1E1E"), false)
	Build.box(self, Vector3(0.12, 0.05, 0.1), Vector3(0.28, 0.83, -0.12), Color("#2E3A44"), false) # the order buttons on the arm
	Build.sphere(self, 0.02, Vector3(0.28, 0.87, -0.12), UiKit.GOOD, 2.0)
	Build.sphere(self, 0.02, Vector3(0.24, 0.87, -0.12), UiKit.BAD, 2.0)
	var plate := Build.label(self, "CAPTAIN", Vector3(0, 1.22, 0.33), 22, UiKit.BRASS)
	plate.rotation.y = PI
	Build.hitbox(self, Vector3(0.6, 1.3, 0.6), Vector3(0, 0.65, 0))
	set_view(Vector3(0, 1.22, 0.05), look)
	bot_arms = Vector2(0.35, 0.35) # on the arm rests


# --- What the captain wants of each post (every peer, from crew state) --------------------

## The line a player on station `sid` sees: what the captain (or the waypoint) wants of him and
## which key does it, or "" when there's nothing to do.
static func hint_for(sid: String, crew: Dictionary, sub: SubState) -> String:
	var want: Dictionary = crew.get("wants", {})
	if want.is_empty() or sub == null:
		return ""
	match sid:
		"helm":
			var out: Array[String] = []
			if want.has("course"):
				var err := wrapf(float(want.course) - sub.heading, -180.0, 180.0)
				if absf(err) > 3.0:
					out.append("come to %03d: %s" % [roundi(float(want.course)) % 360, "D, right rudder" if err > 0.0 else "A, left rudder"])
				elif sub.rudder != 0:
					out.append("steady on %03d: rudder amidships" % (roundi(float(want.course)) % 360))
			if want.has("speed") and int(want.speed) != sub.telegraph:
				out.append("%s: %s" % [SubState.TELEGRAPH_NAMES[int(want.speed)], "W, more speed" if int(want.speed) > sub.telegraph else "S, less speed"])
			return "; ".join(out)
		"dive":
			if float(want.get("depth", -1.0)) >= 0.0 and absf(float(want.depth) - sub.ordered_depth) > 1.0:
				return "make depth %d m: %s" % [roundi(float(want.depth)), "W, deeper" if float(want.depth) > sub.ordered_depth else "S, shallower"]
		"ballast":
			var d := float(want.get("depth", -1.0))
			if d > SubState.AWASH_DEPTH and sub.ballast < 0.99 and not sub.vents_open:
				return "dive: V, open the vents"
			if d >= 0.0 and d <= 0.5 and sub.ballast > 0.0 and sub.blowing == 0 and not sub.is_surfaced():
				return "surface: B, blow the tanks"
		"periscope":
			if want.has("scope") and bool(want.scope) != sub.periscope_raised:
				return "R, %s the periscope" % ("raise" if want.scope else "lower")
		"engine":
			if float(want.get("depth", -1.0)) > SubState.AWASH_DEPTH and sub.diesels.any(func(v: float) -> bool: return v > 0.0):
				return "we're diving: 1 and 2, stop the diesels"
		_:
			if sid.begins_with("tube_") and want.get("attack", false):
				var t: Dictionary = crew.tubes[sid.trim_prefix("tube_").to_int() - 1]
				if not t.loaded:
					return "L, load a torpedo"
				if not t.flooded:
					return "F, flood the tube"
				if not t.door:
					return "O, open the outer door"
				return "Space, fire when the scope says FIRE!"
	return ""


# --- The chair ---------------------------------------------------------------------------

func _build_overlay(root: Control) -> void:
	var box := UiKit.bottom_panel(root)
	box.add_child(UiKit.label("CAPTAIN'S CHAIR", 22, UiKit.BRASS))
	_lines.clear()
	for i in 6:
		var l := UiKit.label("", 16)
		box.add_child(l)
		_lines.append(l)
	box.add_child(UiKit.label("W/S speed   A/D turn (Shift 1°)   R/F depth (Shift 1 m)   1-4 surface / periscope / dive / deep   C crash dive   X twice emergency surface", 14, UiKit.BRASS))
	box.add_child(UiKit.label("Tab target   Space attack it   P periscope   N next place   M clear waypoint   H hologram   Z close-up   Enter PA", 14, UiKit.BRASS))
	box.add_child(UiKit.label(footer(false), 14, UiKit.DIM))


func on_leave() -> void:
	_show_holo(false)
	super.on_leave()


func _process(_delta: float) -> void:
	if overlay == null or _lines.is_empty() or Sim.world == null or Game.instance == null:
		return
	var w := Sim.world
	var sub := w.sub
	var crew := Game.instance.crew
	var want: Dictionary = crew.get("wants", {})
	var course := " → %03d" % (roundi(float(want.course)) % 360) if want.has("course") else ""
	var speed := " → %s" % SubState.TELEGRAPH_NAMES[int(want.speed)].to_upper() if want.has("speed") else ""
	_lines[0].text = "HEADING %03d%s    SPEED %.1f kn %s%s    DEPTH %d m → %d m (test %d)" % [roundi(sub.heading) % 360, course,
		sub.speed * 1.94384, SubState.TELEGRAPH_NAMES[sub.telegraph].to_upper(), speed, roundi(sub.depth), roundi(sub.ordered_depth), roundi(sub.data.test_depth)]
	var wp: Dictionary = crew.get("waypoint", {})
	if wp.is_empty():
		var next := Places.by_distance(w.seabed, sub.pos)
		_lines[1].text = "WAYPOINT none    [N] %s" % ("%s, %.1f km" % [next[0].name, Places.pos(next[0]).distance_to(sub.pos) / 1000.0] if not next.is_empty() else "no places on the chart")
	else:
		var at := Vector2(wp.x, wp.y)
		var r := at.distance_to(sub.pos)
		var eta := r / maxf(sub.speed, 0.5) / 60.0
		_lines[1].text = "WAYPOINT %s    bearing %03d    %.1f km    about %d min" % [wp.name, roundi(ShipState.bearing(sub.pos, at)) % 360, r / 1000.0, ceili(eta)]
	var floor_at := w.seabed.floor_depth(sub.pos)
	var ahead := w.seabed.floor_depth(sub.pos + sub.direction() * 500.0)
	var roof := w.seabed.roof_depth(sub.pos)
	_lines[2].text = "SEA FLOOR %s under us, %s 500 m ahead%s%s" % [_depth_word(floor_at), _depth_word(ahead), "    CAVE ROOF %d m" % roundi(roof) if roof > 0.0 else "",
		"    SHOAL AHEAD!" if ahead < sub.depth + 15.0 else ""]
	_lines[2].modulate = UiKit.WARN if ahead < sub.depth + 15.0 else UiKit.CREAM
	var target := Sim.world.find_ship(int(crew.get("captain_target", -1)))
	if target != null and not target.is_sinking():
		var tr := target.pos.distance_to(sub.pos)
		_lines[3].text = "TARGET %s    bearing %03d    %.1f km    %s" % [target.data.display_name, roundi(ShipState.bearing(sub.pos, target.pos)) % 360, tr / 1000.0,
			"in torpedo reach" if tr < Torpedo.MAX_RANGE * 0.8 else "too far for torpedoes"]
	else:
		_lines[3].text = "TARGET none    [Tab] picks the nearest ship we know of"
	var loaded := 0
	for t: Dictionary in crew.get("tubes", []):
		loaded += 1 if t.loaded else 0
	var trouble := Game.instance.bot_crew.problems() if multiplayer.is_server() else []
	_lines[4].text = "TUBES %d/%d loaded, %d spare    BATTERY %d%%    AIR CO2 %.1f%%  O2 %.1f%%%s" % [loaded, crew.get("tubes", []).size(), int(crew.get("reserve", 0)),
		roundi(sub.battery * 100.0), w.air.co2, w.air.o2, "    " + trouble[0] if not trouble.is_empty() else ""]
	var posts: Array[String] = []
	for sid: String in ["helm", "dive", "ballast", "periscope", "sonar", "tube_1", "engine"]:
		if Game.instance.interior.stations.has(sid):
			var who := Game.instance.station_occupant(sid)
			posts.append("%s %s" % [Game.instance.interior.stations[sid].display_name.to_lower(), "bot" if who < 0 else ("-" if who == 0 else Game.instance.crew_name(who))])
	_lines[5].text = "POSTS  " + "   ".join(posts) + "    (an empty post gets a bot when you order it)"


static func _depth_word(d: float) -> String:
	return "land" if d < 0.0 else "%d m" % roundi(d)


func station_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var fine: bool = event.shift_pressed
	match event.physical_keycode:
		KEY_W:
			order("speed", 1)
		KEY_S:
			order("speed", -1)
		KEY_A:
			order("course", -1.0 if fine else -10.0)
		KEY_D:
			order("course", 1.0 if fine else 10.0)
		KEY_R:
			order("depth", -1.0 if fine else -10.0)
		KEY_F:
			order("depth", 1.0 if fine else 10.0)
		KEY_1, KEY_2, KEY_3, KEY_4:
			order("preset", PRESETS[event.physical_keycode - KEY_1])
		KEY_C:
			order("crash_dive")
		KEY_X:
			var now := Time.get_ticks_msec() / 1000.0
			if now < _confirm_until:
				order("emergency")
				_confirm_until = 0.0
			else:
				_confirm_until = now + 2.0
				Game.instance.hud.show_message("Emergency surface? Press X again.", 2.0)
		KEY_TAB:
			order("target")
		KEY_SPACE:
			order("attack")
		KEY_P:
			order("scope")
		KEY_N:
			order("next_place")
		KEY_M:
			order("clear_place")
		KEY_H:
			_show_holo(_holo_view == null)
		KEY_Z: # the hologram close up round her, or the whole 12 km (every hologram aboard)
			HoloView.close_up = not HoloView.close_up
			Sfx.play_at(self, "click", Vector3(0, 1.0, 0), -6.0)
		KEY_ENTER, KEY_KP_ENTER:
			Game.instance.open_pa() # the PA from the chair (Blaney: "a PA button so that you can type from there")
		_:
			return
	click()


## The navigation room's hologram, everything in it, full on his screen (Blaney).
func _show_holo(on: bool) -> void:
	if not on:
		if _holo_view != null:
			_holo_view.queue_free()
		_holo_view = null
		return
	if overlay == null or _holo_view != null:
		return
	_holo_view = HoloView.screen(true)
	overlay.add_child(_holo_view)
	overlay.move_child(_holo_view, 0)
