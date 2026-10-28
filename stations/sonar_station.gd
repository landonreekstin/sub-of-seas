class_name SonarStation
extends Station
## Passive hydrophones and the active "pinger". The ring shows every contact the
## hydrophones can hear, at its true bearing; train the hydrophone (A/D or mouse) onto one
## to classify it by its screws. P sends a ping: ranges to everything, but everyone hears it.
## Only the operator sees what the enemy is doing (pinging, splashes): call it out.

const HEAR_RANGE := 12000.0
const ECHO_SHOW_TIME := 10.0

var trained := 0.0 ## true bearing of the hydrophone, degrees
var _scope: Control
var _lines: Array[Label] = []
var _echoes: Array = [] ## {b, r} from our last ping
var _echo_time := -INF
var _alerts: Array = [] ## {text, b, until}
var _ping_flash := {} ## ship id -> until (enemy echo-ranging seen on the ring)


func _ready() -> void:
	# Faces -X like the dive station: a console against the port side.
	Build.box(self, Vector3(0.45, 1.0, 1.0), Vector3(-0.1, 0.5, 0), Color("#4A5248"))
	Build.box(self, Vector3(0.25, 0.9, 1.0), Vector3(-0.2, 1.45, 0), Color("#3A3F38"))
	Build.cyl(self, 0.26, 0.04, Vector3(-0.06, 1.45, 0), Color("#0E2A1A"), Vector3.RIGHT)
	Build.cyl(self, 0.2, 0.05, Vector3(-0.05, 1.45, 0), Color("#164A2A"), Vector3.RIGHT)
	Build.box(self, Vector3(0.02, 0.012, 0.36), Vector3(-0.02, 1.45, 0), Color("#2FD06A"), false) # sweep line
	Build.sphere(self, 0.06, Vector3(0.1, 1.02, -0.3), Color("#2B2B26")) # headphones
	Build.sphere(self, 0.06, Vector3(0.1, 1.02, -0.12), Color("#2B2B26"))
	Build.wheel(self, 0.12, Vector3(0.14, 0.9, 0.25), Color("#C9A04A"), Vector3.UP) # training handwheel
	var l := Build.label(self, "SONAR", Vector3(-0.07, 1.82, 0), 28)
	l.rotation.y = PI / 2.0
	Build.hitbox(self, Vector3(0.6, 1.9, 1.0), Vector3(0.05, 0.95, 0))
	set_view(Vector3(0.85, 1.6, 0), Vector3(0, 1.3, 0))
	Sim.event.connect(_on_sim_event)


## What the hydrophones hear from one ship: 0 (nothing) .. 1 (loud).
static func loudness(ship: ShipState, sub: SubState) -> float:
	if ship.is_sinking():
		return 0.0
	var d := ship.pos.distance_to(sub.pos)
	if d > HEAR_RANGE:
		return 0.0
	var screws := 0.25 + 0.75 * ship.speed / (ship.data.max_speed_kn * SubState.KNOT)
	var own := absf(sub.speed) / (sub.data.submerged_speed_kn * SubState.KNOT)
	return clampf(screws * (1.0 - d / HEAR_RANGE) * 1.6 - own * 0.35, 0.0, 1.0)


static func classify(ship: ShipState) -> String:
	var kn := ship.speed / SubState.KNOT
	var turns := "turns for about %d knots" % (roundi(kn / 2.0) * 2)
	if ship.data.asw:
		return "fast light screws — WARSHIP, %s" % turns
	return "slow heavy screws — merchant, %s" % turns


func _on_sim_event(kind: String, data: Dictionary) -> void:
	if Sim.world == null:
		return
	var sub := Sim.world.sub
	var now := Sim.world.time
	match kind:
		"ping":
			_ping_flash[data.ship] = now + 1.5
			if data.echo:
				_alert("ECHO-RANGING — he has us!", Vector2(data.x, data.y), now)
		"splash":
			_alert("SPLASHES! Depth charges in the water", Vector2(data.x, data.y), now)
		"own_ping":
			_echoes = data.echoes
			_echo_time = now


func _alert(text: String, at: Vector2, now: float) -> void:
	var b := ShipState.bearing(Sim.world.sub.pos, at)
	_alerts.push_front({"text": "%s  brg %03d" % [text, roundi(b)], "until": now + 8.0})
	_alerts.resize(mini(_alerts.size(), 3))


func _process(_delta: float) -> void:
	if overlay == null or Sim.world == null:
		return
	_scope.queue_redraw()
	var sub := Sim.world.sub
	var now := Sim.world.time
	var best: ShipState = null
	var best_off := 6.0
	for ship in Sim.world.ships:
		var off := absf(wrapf(ShipState.bearing(sub.pos, ship.pos) - trained, -180.0, 180.0))
		if off < best_off and loudness(ship, sub) > 0.05:
			best_off = off
			best = ship
	_lines[0].text = "HYDROPHONE  %03d°   own heading %03d°   [A/D or mouse] train" % [roundi(trained) % 360, roundi(sub.heading) % 360]
	if broken:
		_lines[1].text = "Static. The sonar gear is damaged."
	elif best != null:
		_lines[1].text = "CONTACT %03d°  %s" % [roundi(ShipState.bearing(sub.pos, best.pos)), classify(best)]
	else:
		_lines[1].text = "Nothing on this bearing."
	var a := ""
	for al: Dictionary in _alerts:
		if al.until > now:
			a += al.text + "\n"
	_lines[2].text = a.strip_edges()
	var echo := ""
	if now - _echo_time < ECHO_SHOW_TIME:
		echo = "PING: " + ("no echoes" if _echoes.is_empty() else ", ".join(_echoes.map(func(e: Dictionary) -> String:
			return "%03d° %d m" % [roundi(e.b), roundi(e.r / 50.0) * 50])))
	_lines[3].text = echo


func _build_overlay(root: Control) -> void:
	_scope = Control.new()
	_scope.custom_minimum_size = Vector2(340, 340)
	_scope.draw.connect(_draw_scope)
	root.add_child(_scope)
	_scope.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_scope.position.y = 120
	_scope.position.x -= 170
	var box := UiKit.bottom_panel(root)
	box.add_child(UiKit.label("SONAR", 22, UiKit.BRASS))
	_lines.clear()
	for i in 4:
		var l := UiKit.label("", 18, UiKit.CREAM if i < 2 else (UiKit.BAD if i == 2 else UiKit.GOOD))
		box.add_child(l)
		_lines.append(l)
	box.add_child(UiKit.label("[P] active ping (gives range, gives us away)    " + footer(cluster != ""), 14, UiKit.DIM))


func _draw_scope() -> void:
	var c := _scope.size * 0.5
	var r := minf(c.x, c.y) - 8.0
	var green := Color("#2FD06A")
	_scope.draw_circle(c, r + 6.0, Color(0.02, 0.08, 0.04, 0.92))
	_scope.draw_arc(c, r, 0, TAU, 64, Color(green, 0.6), 2.0)
	_scope.draw_arc(c, r * 0.5, 0, TAU, 48, Color(green, 0.2), 1.0)
	if Sim.world == null:
		return
	var sub := Sim.world.sub
	var now := Sim.world.time
	var dir := func(b: float) -> Vector2: return Vector2(sin(deg_to_rad(b)), -cos(deg_to_rad(b)))
	for i in 12:
		var b := i * 30.0
		_scope.draw_line(c + dir.call(b) * r * 0.94, c + dir.call(b) * r, Color(green, 0.5), 1.0)
	_scope.draw_string(_scope.get_theme_default_font(), c + Vector2(-5, -r + 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(green, 0.7))
	_scope.draw_line(c, c + dir.call(sub.heading) * r * 0.35, Color(UiKit.CREAM, 0.6), 2.0) # own bow
	_scope.draw_line(c, c + dir.call(trained) * r, Color(UiKit.BRASS, 0.8), 2.0)
	if broken:
		for i in 60:
			var p := c + Vector2(randf_range(-r, r), randf_range(-r, r)) * 0.7
			_scope.draw_circle(p, 1.5, Color(green, 0.5))
		return
	for ship in Sim.world.ships:
		var loud := loudness(ship, sub)
		if loud <= 0.02:
			continue
		var jitter := sin(now * 1.7 + ship.id) * 2.0
		var b := ShipState.bearing(sub.pos, ship.pos) + jitter
		var col := Color(green, clampf(loud * 1.5, 0.25, 1.0))
		_scope.draw_line(c + dir.call(b) * r * (0.9 - loud * 0.5), c + dir.call(b) * r * 0.98, col, 3.0 + loud * 3.0)
		if _ping_flash.get(ship.id, -INF) > now:
			_scope.draw_circle(c + dir.call(b) * r * 1.0, 7.0, Color(UiKit.BAD, 0.9))
	if now - _echo_time < ECHO_SHOW_TIME:
		for e: Dictionary in _echoes:
			var rr := clampf(e.r / 6000.0, 0.05, 1.0) * r
			_scope.draw_circle(c + dir.call(e.b) * rr, 5.0, UiKit.GOOD)


func station_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		trained = fposmod(trained + event.relative.x * 0.15, 360.0)
	elif key_pressed(event, KEY_A):
		trained = fposmod(trained - 5.0, 360.0)
	elif key_pressed(event, KEY_D):
		trained = fposmod(trained + 5.0, 360.0)
	elif key_pressed(event, KEY_P):
		order("ping")
