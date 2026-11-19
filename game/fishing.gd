class_name Fishing
extends CanvasLayer
## Fishing off the stern (Blaney: fishing off the deck). Cast, wait for a bite, [Space] to strike
## while the float is under, then reel: hold [LMB] (or Space) to wind in, which tightens the
## line; let go to ease it. Keep the tension in the green while the fish runs and you land it;
## too tight and the line snaps, slack too long and it throws the hook. The catch goes to the
## host (Game.rq_fish) and up on the T card's records. [Q] or [E] puts the rod down.

var _phase := "cast"
var _t := 0.0
var _bite_at := 0.0
var _tension := 0.4
var _landed := 0.0
var _slack := 0.0
var _fish: Array = []
var _rng := RandomNumberGenerator.new()
var _lines: Array[Label] = []


func _ready() -> void:
	_rng.randomize()
	var root := UiKit.overlay_root()
	root.theme = UiKit.theme()
	add_child(root)
	var box := UiKit.bottom_panel(root)
	box.add_child(UiKit.label("FISHING OFF THE STERN", 22, UiKit.BRASS))
	for k in 3:
		var l := UiKit.label("", 18 if k < 2 else 14, UiKit.CREAM if k < 2 else UiKit.DIM)
		box.add_child(l)
		_lines.append(l)
	_cast()


func _cast() -> void:
	_phase = "wait"
	_t = 0.0
	_bite_at = _rng.randf_range(4.0, 12.0)
	Sfx.play("splash", -14.0, 1.4)


func _reeling() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_SPACE)


func _process(delta: float) -> void:
	_t += delta
	match _phase:
		"wait":
			_lines[0].text = "The float bobs on the swell%s" % ".".repeat(int(_t * 2.0) % 4)
			_lines[1].text = ""
			if _t >= _bite_at:
				_phase = "bite"
				_t = 0.0
				Sfx.play("splash", -6.0, 0.9)
		"bite":
			_lines[0].text = ">>> IT'S UNDER! STRIKE! <<<"
			if _t > 1.3:
				_say("Too slow, it took the bait and went.")
		"reel":
			# The fish runs and rests; winding in tightens, easing off lets it slacken.
			var pull := 0.35 + 0.35 * sin(_t * 1.3 + float(_fish[0])) + 0.25 * sin(_t * 3.1)
			_tension = clampf(_tension + ((0.9 if _reeling() else -0.75) + pull * 0.6 - 0.3) * delta, 0.0, 1.0)
			var green := _tension >= 0.3 and _tension <= 0.75
			if green and _reeling():
				_landed += delta / (4.0 + float(_fish[1]) * 0.08)
			_slack = _slack + delta if _tension < 0.15 else 0.0
			var cells := 25
			var bar := ""
			for k in cells:
				var v := float(k) / (cells - 1)
				bar += "▼" if absi(k - roundi(_tension * (cells - 1))) == 0 else ("█" if v >= 0.3 and v <= 0.75 else "─")
			_lines[0].text = "SLACK  %s  SNAP" % bar
			_lines[1].text = "Landing it: %d%%" % roundi(_landed * 100.0)
			if _tension >= 1.0:
				_say("SNAP! The line parted. Tie on a new hook...")
			elif _slack > 2.0:
				_say("The line went slack and it threw the hook.")
			elif _landed >= 1.0:
				var name: String = Pastimes.FISH[int(_fish[0])][0]
				Game.instance.rq_fish.rpc_id(1, int(_fish[0]), float(_fish[1]))
				_say("Landed! A %.1f kg %s." % [_fish[1], name] if name != "old boot" else "Landed... an old boot.")
		"said":
			if _t > 2.5:
				_cast()
	_lines[2].text = ("hold [LMB] to reel in, let go to ease off" if _phase == "reel" else "[Space] strike when the float goes under") + "    [Q] or [E] put the rod down"


func _say(text: String) -> void:
	_phase = "said"
	_t = 0.0
	_lines[0].text = text
	_lines[1].text = ""


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_SPACE:
		if _phase == "bite":
			_phase = "reel"
			_t = 0.0
			_tension = 0.45
			_landed = 0.0
			_fish = Pastimes.catch_fish(_rng)
			Sfx.play("splash", -4.0, 0.7)
		elif _phase == "wait":
			_say("Struck at nothing. Patience...")
		get_viewport().set_input_as_handled()
	elif event.is_action("leave_station"):
		get_viewport().set_input_as_handled()
		queue_free()
