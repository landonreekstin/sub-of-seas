class_name ArmStation
extends Station
## A seat at the arm-wrestling table in the mess (Blaney: arm wrestling). Two sit down across
## the table (a bot will take on all comers: B at the empty seat) and hammer Space; the host
## moves the locked hands (Pastimes.arm_*), and whoever drives the other's to the table wins.
## The seat facing +X (`arm_a`) also draws the two arms in the middle.

var seated := true
var reach := 0.68 ## from the seat to the middle of the table
var top := 0.79 ## the table top
var _pivot: Node3D
var _presses := 0
var _send := 0.0
var _lines: Array[Label] = []


func _ready() -> void:
	Build.area(self, Vector3(0.55, 0.3, 0.5), Vector3(0, top + 0.1, -reach * 0.55))
	set_view(Vector3(0, 1.15, 0.05), Vector3(0, top + 0.25, -reach))
	bot_arms = Vector2(0.3, 1.4)
	bot_lean = 0.3
	if station_id != Pastimes.ARM[0]:
		return
	_pivot = Node3D.new()
	_pivot.position = Vector3(0, top + 0.02, -reach)
	add_child(_pivot)
	var hands := Vector3(0, 0.3, 0)
	for side in [1.0, -1.0]: # our forearm, then his from across the table
		var elbow := Vector3(side * 0.06, 0.03, side * 0.24)
		var arm := Build.cyl(_pivot, 0.04, elbow.distance_to(hands), (elbow + hands) * 0.5, Living.SKIN, (hands - elbow).normalized())
		arm.name = "Arm"
		Build.cyl(_pivot, 0.045, 0.12, elbow + Vector3(0, 0.0, side * 0.03), Color("#F2F0E8"), Vector3.BACK) # a rolled-up sleeve
	Build.sphere(_pivot, 0.065, hands, Living.SKIN) # the locked fists


func _process(delta: float) -> void:
	var arm: Dictionary = Game.instance.crew.get("arm", {}) if Game.instance != null else {}
	if _pivot != null:
		# + pos: the far seat is winning, the hands go down on our side.
		_pivot.rotation.x = lerp_angle(_pivot.rotation.x, deg_to_rad(80.0) * float(arm.get("pos", 0.0)), clampf(delta * 10.0, 0.0, 1.0))
	if overlay == null:
		return
	_send -= delta
	if _presses > 0 and _send <= 0.0:
		order("push", _presses)
		_presses = 0
		_send = 0.2
	var other := Game.instance._seated(Pastimes.ARM[1] if station_id == Pastimes.ARM[0] else Pastimes.ARM[0])
	if other == "":
		_lines[0].text = "Waiting for someone across the table...  ([%s] at the empty seat sits a bot down)" % OS.get_keycode_string(Settings.key_for("bot"))
		_lines[1].text = ""
		return
	var mine := -float(arm.get("pos", 0.0)) if station_id == Pastimes.ARM[0] else float(arm.get("pos", 0.0)) # + = we're winning
	var cells := 21
	var at := clampi(roundi((mine + 1.0) * 0.5 * (cells - 1)), 0, cells - 1)
	var bar := ""
	for k in cells:
		bar += "●" if k == at else ("═" if k != cells / 2 else "|")
	_lines[0].text = "%s  %s  YOU" % [other, bar] if arm.get("on", false) else "Get ready... the next bout is about to start"
	var wins: Dictionary = Game.instance.crew.get("arm_wins", {})
	_lines[1].text = "Wins: you %d   %s %d" % [int(wins.get(Game.instance.crew_name(multiplayer.get_unique_id()), 0)), other, int(wins.get(other, 0))]


func _build_overlay(root: Control) -> void:
	var box := UiKit.bottom_panel(root)
	box.add_child(UiKit.label("ARM WRESTLING", 22, UiKit.BRASS))
	_lines.clear()
	for k in 2:
		var l := UiKit.label()
		box.add_child(l)
		_lines.append(l)
	box.add_child(UiKit.label("[Space] tap as fast as you can — drive his hand to the table    " + footer(false), 14, UiKit.DIM))


func station_input(event: InputEvent) -> void:
	if key_pressed(event, KEY_SPACE) and not event.is_echo():
		_presses += 1
