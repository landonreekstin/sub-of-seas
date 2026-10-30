class_name BotOrders
extends Control
## Orders for a bot crewman (E at the bot): his station's own orders, T to switch between
## following orders and acting on his own, B to stand him down; E, Q or Esc closes.

var station_id := ""
var _lines: Array[Label] = []


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiKit.bottom_panel(self)
	for i in 4:
		var l := UiKit.label("", 22 if i == 0 else 17, UiKit.BRASS if i == 0 else (UiKit.DIM if i == 3 else UiKit.CREAM))
		box.add_child(l)
		_lines.append(l)


func _bot() -> Dictionary:
	return Game.instance.crew.get("bots", {}).get(station_id, {})


func _process(_delta: float) -> void:
	var b := _bot()
	if b.is_empty():
		close()
		return
	var sub := Sim.world.sub
	_lines[0].text = "%s — %s" % [b.name.to_upper(), BotCrew.job(station_id)]
	_lines[1].text = "ON HIS OWN: he works the station as he sees fit" if b.auto else "ON ORDERS: " + _orders_now(b, sub)
	_lines[2].text = _keys()
	_lines[3].text = "[T] %s    [B] stand him down    [E/Q/Esc] close" % ("give him orders" if b.auto else "let him act on his own")


func _orders_now(b: Dictionary, sub: SubState) -> String:
	match station_id:
		"helm":
			return "course %03d°, %s" % [roundi(b.course) % 360, SubState.TELEGRAPH_NAMES[int(b.speed)]]
		"dive":
			return "depth %d m" % roundi(b.depth)
	return "standing by for your word"


func _keys() -> String:
	if station_id.begins_with("tube_"):
		return "[F] fire when ready"
	match station_id:
		"helm":
			return "[A/D] course ±10°    [W/S] speed"
		"dive":
			return "[W/S] depth ±5 m    [1] surface  [2] periscope depth  [3] 45 m  [4] test depth"
		"periscope":
			return "[M] mark the nearest ship"
		"sonar":
			return "[P] report the loudest contact"
		"ballast":
			return "[V] flood the tanks    [L] blow them"
	return ""


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	get_viewport().set_input_as_handled()
	var k: Key = event.physical_keycode
	var sub := Sim.world.sub
	if k in [KEY_E, KEY_Q, KEY_ESCAPE]:
		close()
	elif k == KEY_T:
		_send("auto")
	elif k == Settings.key_for("bot"):
		_send("dismiss")
		close()
	elif station_id == "helm" and k in [KEY_A, KEY_D, KEY_W, KEY_S]:
		if _bot().auto:
			_send("auto")
		_send("course" if k in [KEY_A, KEY_D] else "speed", (-10 if k == KEY_A else 10) if k in [KEY_A, KEY_D] else (1 if k == KEY_W else -1))
	elif station_id == "dive" and k in [KEY_W, KEY_S, KEY_1, KEY_2, KEY_3, KEY_4]:
		if _bot().auto:
			_send("auto")
		match k:
			KEY_W:
				_send("depth", -5.0)
			KEY_S:
				_send("depth", 5.0)
			_:
				_send("depth_to", [0.0, float(sub.data.periscope_depth), 45.0, float(sub.data.test_depth)][k - KEY_1])
	elif station_id.begins_with("tube_") and k == KEY_F:
		_send("fire")
	elif station_id == "periscope" and k == KEY_M:
		_send("mark")
	elif station_id == "sonar" and k == KEY_P:
		_send("report")
	elif station_id == "ballast" and k == KEY_V:
		_send("vent")
	elif station_id == "ballast" and k == KEY_L:
		_send("blow")


func _send(key: String, value: Variant = null) -> void:
	Game.instance.rq_bot.rpc_id(1, station_id, key, value)


func close() -> void:
	if Game.instance != null and Game.instance.bot_orders == self:
		Game.instance.bot_orders = null
	queue_free()
